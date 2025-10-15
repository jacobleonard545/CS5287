#!/usr/bin/env python3

import json
import logging
import time
import statistics
import os
from datetime import datetime, timezone
from collections import deque
from kafka import KafkaConsumer
from kafka.errors import KafkaError
from influxdb_client import InfluxDBClient, Point, WritePrecision
from influxdb_client.client.write_api import SYNCHRONOUS

# Configuration from environment variables
KAFKA_BROKER = os.getenv('KAFKA_BROKER', 'kafka-service:9092')
KAFKA_TOPIC = os.getenv('KAFKA_TOPIC', 'conveyor-speed')
CONSUMER_GROUP = os.getenv('KAFKA_CONSUMER_GROUP', 'data-processor-group')

# InfluxDB Configuration
INFLUXDB_URL = os.getenv('INFLUXDB_URL', 'http://influxdb-service:8086')
INFLUXDB_TOKEN = os.getenv('INFLUXDB_TOKEN', '')
INFLUXDB_ORG = os.getenv('INFLUXDB_ORG', 'conveyor-org')
INFLUXDB_BUCKET = os.getenv('INFLUXDB_BUCKET', 'conveyor-data')

# Analytics Configuration
WINDOW_SIZE = int(os.getenv('WINDOW_SIZE', '10'))

# Logging setup
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class ConveyorDataProcessor:
    def __init__(self):
        self.consumer = None
        self.influx_client = None
        self.write_api = None
        self.processed_count = 0
        self.rolling_window = deque(maxlen=WINDOW_SIZE)
        self.last_speed = 0.0
        self.last_state = "unknown"

    def connect_kafka(self):
        """Connect to Kafka consumer"""
        max_retries = 10
        retry_delay = 5

        for attempt in range(max_retries):
            try:
                logger.info(f"Connecting to Kafka: {KAFKA_BROKER} (attempt {attempt + 1})")
                self.consumer = KafkaConsumer(
                    KAFKA_TOPIC,
                    bootstrap_servers=[KAFKA_BROKER],
                    group_id=CONSUMER_GROUP,
                    value_deserializer=lambda x: json.loads(x.decode('utf-8')),
                    auto_offset_reset='latest',
                    enable_auto_commit=True,
                    consumer_timeout_ms=1000
                )
                logger.info("Connected to Kafka successfully!")
                return True

            except Exception as e:
                logger.error(f"Failed to connect to Kafka (attempt {attempt + 1}): {e}")
                if attempt < max_retries - 1:
                    logger.info(f"Retrying in {retry_delay} seconds...")
                    time.sleep(retry_delay)
                else:
                    logger.error("Max retries reached. Unable to connect to Kafka.")
                    return False

    def connect_influxdb(self):
        """Connect to InfluxDB"""
        max_retries = 10
        retry_delay = 5

        for attempt in range(max_retries):
            try:
                logger.info(f"Connecting to InfluxDB: {INFLUXDB_URL} (attempt {attempt + 1})")
                self.influx_client = InfluxDBClient(
                    url=INFLUXDB_URL,
                    token=INFLUXDB_TOKEN,
                    org=INFLUXDB_ORG
                )
                self.write_api = self.influx_client.write_api(write_options=SYNCHRONOUS)

                # Test connection
                health = self.influx_client.health()
                if health.status == "pass":
                    logger.info("Connected to InfluxDB successfully!")
                    return True
                else:
                    raise Exception(f"InfluxDB health check failed: {health.message}")

            except Exception as e:
                logger.error(f"Failed to connect to InfluxDB (attempt {attempt + 1}): {e}")
                if attempt < max_retries - 1:
                    logger.info(f"Retrying in {retry_delay} seconds...")
                    time.sleep(retry_delay)
                else:
                    logger.error("Max retries reached. Unable to connect to InfluxDB.")
                    return False

    def detect_anomalies(self, current_speed, current_state):
        """Detect anomalies in conveyor data"""
        anomalies = []

        # Speed-based anomalies
        if current_speed > 0.25:
            anomalies.append("speed_high")

        # State-based anomalies
        if current_state == "stopped" and current_speed > 0.01:
            anomalies.append("unexpected_movement")

        if current_state in ["stopped", "stopping"] and self.last_state == "running":
            anomalies.append("unexpected_stop")

        # Rate of change anomaly
        if len(self.rolling_window) >= 2:
            speed_change = abs(current_speed - self.last_speed)
            if speed_change > 0.1:
                anomalies.append("rapid_change")

        return anomalies

    def calculate_rolling_metrics(self, current_speed):
        """Calculate rolling window analytics"""
        self.rolling_window.append(current_speed)

        if len(self.rolling_window) < 2:
            return {
                'rolling_avg': current_speed,
                'rolling_max': current_speed,
                'rolling_min': current_speed
            }

        speeds = list(self.rolling_window)
        return {
            'rolling_avg': statistics.mean(speeds),
            'rolling_max': max(speeds),
            'rolling_min': min(speeds)
        }

    def determine_alert_level(self, anomalies):
        """Determine alert level based on anomalies"""
        if not anomalies:
            return "normal"
        elif len(anomalies) == 1 and "speed_high" in anomalies:
            return "normal"
        else:
            return "high"

    def process_message(self, message):
        """Process a single conveyor message"""
        try:
            # Extract data
            timestamp = message.get('timestamp')
            conveyor_id = message.get('conveyor_id', 'unknown')
            speed_ms = float(message.get('speed_ms', 0.0))
            state = message.get('state', 'unknown')

            # Calculate rolling metrics
            rolling_metrics = self.calculate_rolling_metrics(speed_ms)

            # Detect anomalies
            anomalies = self.detect_anomalies(speed_ms, state)
            alert_level = self.determine_alert_level(anomalies)

            # Convert units
            speed_kmh = speed_ms * 3.6

            # Create InfluxDB point
            point = Point("conveyor_speed") \
                .tag("conveyor_id", conveyor_id) \
                .tag("state", state) \
                .tag("alert_level", alert_level) \
                .field("speed_ms", speed_ms) \
                .field("speed_kmh", speed_kmh) \
                .field("rolling_avg", rolling_metrics['rolling_avg']) \
                .field("rolling_max", rolling_metrics['rolling_max']) \
                .field("rolling_min", rolling_metrics['rolling_min']) \
                .field("anomaly_count", len(anomalies)) \
                .field("anomalies", ",".join(anomalies) if anomalies else "none") \
                .field("message_sequence", self.processed_count + 1) \
                .field("window_size", len(self.rolling_window))

            if timestamp:
                try:
                    dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
                    point = point.time(dt, WritePrecision.NS)
                except:
                    point = point.time(datetime.now(timezone.utc), WritePrecision.NS)
            else:
                point = point.time(datetime.now(timezone.utc), WritePrecision.NS)

            # Write to InfluxDB
            self.write_api.write(bucket=INFLUXDB_BUCKET, org=INFLUXDB_ORG, record=point)

            self.processed_count += 1
            self.last_speed = speed_ms
            self.last_state = state

            # Log every 10th message
            if self.processed_count % 10 == 0:
                logger.info(f"InfluxDB write #{self.processed_count}: speed={speed_ms:.3f}m/s, "
                          f"avg={rolling_metrics['rolling_avg']:.3f}, state={state}, "
                          f"anomalies={len(anomalies)}, alert={alert_level}")

            return True

        except Exception as e:
            logger.error(f"Error processing message: {e}")
            return False

    def run(self):
        """Main processor loop"""
        if not self.connect_kafka():
            return

        if not self.connect_influxdb():
            return

        logger.info("Starting data processing pipeline...")
        logger.info(f"Kafka topic: {KAFKA_TOPIC}")
        logger.info(f"InfluxDB bucket: {INFLUXDB_BUCKET}")
        logger.info(f"Rolling window size: {WINDOW_SIZE}")

        try:
            while True:
                try:
                    # Poll for messages
                    message_pack = self.consumer.poll(timeout_ms=1000)

                    if message_pack:
                        for topic_partition, messages in message_pack.items():
                            for message in messages:
                                if not self.process_message(message.value):
                                    logger.warning("Failed to process message, continuing...")

                    # Commit offsets periodically
                    if self.processed_count % 100 == 0 and self.processed_count > 0:
                        self.consumer.commit()
                        logger.info(f"Processed {self.processed_count} messages total")

                except KafkaError as e:
                    logger.error(f"Kafka error: {e}")
                    time.sleep(5)

        except KeyboardInterrupt:
            logger.info("Processor stopped by user")
        except Exception as e:
            logger.error(f"Processor error: {e}")
        finally:
            if self.consumer:
                self.consumer.close()
            if self.influx_client:
                self.influx_client.close()
            logger.info("Processor connections closed")

if __name__ == "__main__":
    processor = ConveyorDataProcessor()
    processor.run()
