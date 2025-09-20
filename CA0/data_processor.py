#!/usr/bin/env python3
"""
Data Processor for Conveyor Speed Pipeline
Consumes from Kafka 'conveyor-speed' topic
Transforms and enriches data
Outputs to console (later will send to InfluxDB)
"""

import json
import time
import statistics
from datetime import datetime, timezone
from collections import deque
from kafka import KafkaConsumer
from kafka.errors import KafkaError
from influxdb_client import InfluxDBClient, Point, WritePrecision
from influxdb_client.client.write_api import SYNCHRONOUS
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configuration
KAFKA_BROKER = '18.217.38.119:9092'  # kafka-hub instance
KAFKA_TOPIC = 'conveyor-speed'
CONSUMER_GROUP = 'data-processor-group'

# InfluxDB Configuration
INFLUXDB_URL = 'http://18.224.136.43:8086'
INFLUXDB_TOKEN = 'ca0-conveyor-token-2025'
INFLUXDB_ORG = 'CA0'
INFLUXDB_BUCKET = 'conveyor_data'

class DataProcessor:
    def __init__(self, window_size=10):
        self.consumer = None
        self.influx_client = None
        self.write_api = None
        self.window_size = window_size
        self.speed_window = deque(maxlen=window_size)  # Rolling window for calculations
        self.message_count = 0
        self.start_time = time.time()

    def connect_kafka(self):
        """Initialize Kafka consumer connection"""
        try:
            self.consumer = KafkaConsumer(
                KAFKA_TOPIC,
                bootstrap_servers=[KAFKA_BROKER],
                group_id=CONSUMER_GROUP,
                value_deserializer=lambda v: json.loads(v.decode('utf-8')),
                auto_offset_reset='latest',  # Start from latest messages
                enable_auto_commit=True
                # Removed timeout - will wait indefinitely for messages
            )
            logger.info(f"Connected to Kafka broker: {KAFKA_BROKER}")
            logger.info(f"Subscribed to topic: {KAFKA_TOPIC}")
            return True
        except Exception as e:
            logger.error(f"Failed to connect to Kafka: {e}")
            return False

    def connect_influxdb(self):
        """Initialize InfluxDB client connection"""
        try:
            self.influx_client = InfluxDBClient(
                url=INFLUXDB_URL,
                token=INFLUXDB_TOKEN,
                org=INFLUXDB_ORG
            )
            self.write_api = self.influx_client.write_api(write_options=SYNCHRONOUS)

            # Test connection
            health = self.influx_client.health()
            if health.status == "pass":
                logger.info(f"Connected to InfluxDB: {INFLUXDB_URL}")
                logger.info(f"Organization: {INFLUXDB_ORG}, Bucket: {INFLUXDB_BUCKET}")
                return True
            else:
                logger.error(f"InfluxDB health check failed: {health.message}")
                return False
        except Exception as e:
            logger.error(f"Failed to connect to InfluxDB: {e}")
            return False

    def calculate_statistics(self, current_speed):
        """Calculate rolling statistics"""
        self.speed_window.append(current_speed)

        if len(self.speed_window) < 2:
            return {
                'avg_speed': current_speed,
                'min_speed': current_speed,
                'max_speed': current_speed,
                'speed_trend': 'stable',
                'window_size': len(self.speed_window)
            }

        speeds = list(self.speed_window)
        avg_speed = statistics.mean(speeds)
        min_speed = min(speeds)
        max_speed = max(speeds)

        # Simple trend analysis
        if len(speeds) >= 3:
            recent_avg = statistics.mean(speeds[-3:])
            older_avg = statistics.mean(speeds[:-3]) if len(speeds) > 3 else avg_speed

            if recent_avg > older_avg * 1.05:  # 5% increase
                trend = 'increasing'
            elif recent_avg < older_avg * 0.95:  # 5% decrease
                trend = 'decreasing'
            else:
                trend = 'stable'
        else:
            trend = 'stable'

        return {
            'avg_speed': round(avg_speed, 3),
            'min_speed': round(min_speed, 3),
            'max_speed': round(max_speed, 3),
            'speed_trend': trend,
            'window_size': len(self.speed_window)
        }

    def detect_anomalies(self, current_speed, stats):
        """Simple anomaly detection"""
        anomalies = []

        # Speed out of normal range
        if current_speed > 0.28:  # Close to max limit
            anomalies.append('speed_high')
        elif current_speed == 0.0 and len(self.speed_window) > 1:
            prev_speeds = [s for s in list(self.speed_window)[:-1] if s > 0]
            if prev_speeds and statistics.mean(prev_speeds) > 0.1:
                anomalies.append('unexpected_stop')

        # Rapid speed changes
        if len(self.speed_window) >= 2:
            speed_change = abs(current_speed - self.speed_window[-2])
            if speed_change > 0.1:  # More than 0.1 m/s change
                anomalies.append('rapid_change')

        return anomalies

    def transform_message(self, raw_message):
        """Transform and enrich the raw Kafka message"""
        try:
            # Extract core data
            timestamp = raw_message.get('timestamp')
            conveyor_id = raw_message.get('conveyor_id')
            speed_ms = raw_message.get('speed_ms', 0.0)
            state = raw_message.get('state', 'unknown')

            # Calculate statistics
            stats = self.calculate_statistics(speed_ms)

            # Detect anomalies
            anomalies = self.detect_anomalies(speed_ms, stats)

            # Create enriched message
            processed_message = {
                'timestamp': timestamp,
                'processed_at': datetime.now(timezone.utc).isoformat(),
                'conveyor_id': conveyor_id,
                'measurements': {
                    'speed_ms': speed_ms,
                    'speed_kmh': round(speed_ms * 3.6, 3),  # Convert to km/h
                    'state': state
                },
                'analytics': {
                    'rolling_avg': stats['avg_speed'],
                    'rolling_min': stats['min_speed'],
                    'rolling_max': stats['max_speed'],
                    'trend': stats['speed_trend'],
                    'window_size': stats['window_size']
                },
                'alerts': {
                    'anomalies': anomalies,
                    'alert_level': 'high' if anomalies else 'normal'
                },
                'metadata': {
                    'processor_id': 'data-processor-001',
                    'message_sequence': self.message_count,
                    'processing_latency_ms': 0  # Will calculate if needed
                }
            }

            return processed_message

        except Exception as e:
            logger.error(f"Error transforming message: {e}")
            return None

    def write_to_influxdb(self, processed_message):
        """Write processed data to InfluxDB"""
        try:
            # Extract data
            timestamp = processed_message['timestamp']
            conveyor_id = processed_message['conveyor_id']
            measurements = processed_message['measurements']
            analytics = processed_message['analytics']
            alerts = processed_message['alerts']

            # Create InfluxDB Point
            point = Point("conveyor_speed") \
                .tag("conveyor_id", conveyor_id) \
                .tag("state", measurements['state']) \
                .tag("alert_level", alerts['alert_level']) \
                .field("speed_ms", measurements['speed_ms']) \
                .field("speed_kmh", measurements['speed_kmh']) \
                .field("rolling_avg", analytics['rolling_avg']) \
                .field("rolling_min", analytics['rolling_min']) \
                .field("rolling_max", analytics['rolling_max']) \
                .field("window_size", analytics['window_size']) \
                .field("message_sequence", processed_message['metadata']['message_sequence']) \
                .time(timestamp, WritePrecision.NS)

            # Add anomaly fields
            if alerts['anomalies']:
                point.field("anomaly_count", len(alerts['anomalies']))
                point.field("anomalies", ','.join(alerts['anomalies']))
            else:
                point.field("anomaly_count", 0)

            # Write to InfluxDB
            self.write_api.write(bucket=INFLUXDB_BUCKET, record=point)
            return True

        except Exception as e:
            logger.error(f"Error writing to InfluxDB: {e}")
            return False

    def output_processed_data(self, processed_message):
        """Output processed data to console and InfluxDB"""
        try:
            # Console output
            speed = processed_message['measurements']['speed_ms']
            avg_speed = processed_message['analytics']['rolling_avg']
            state = processed_message['measurements']['state']
            anomalies = processed_message['alerts']['anomalies']

            log_msg = f"[PROCESSED] Speed: {speed:.3f} m/s | Avg: {avg_speed:.3f} | State: {state}"
            if anomalies:
                log_msg += f" | ALERTS: {', '.join(anomalies)}"

            # Write to InfluxDB
            influx_success = self.write_to_influxdb(processed_message)
            if influx_success:
                log_msg += " | ✅ InfluxDB"
            else:
                log_msg += " | ❌ InfluxDB"

            logger.info(log_msg)

            # Write to local file for verification
            with open('/tmp/processed_data.jsonl', 'a') as f:
                f.write(json.dumps(processed_message) + '\n')

            return True

        except Exception as e:
            logger.error(f"Error outputting processed data: {e}")
            return False

    def run(self):
        """Main processing loop"""
        logger.info("Starting Data Processor")
        logger.info(f"Source: {KAFKA_TOPIC} @ {KAFKA_BROKER}")
        logger.info(f"Destination: InfluxDB @ {INFLUXDB_URL}")
        logger.info(f"Consumer Group: {CONSUMER_GROUP}")
        logger.info(f"Rolling window size: {self.window_size}")

        if not self.connect_kafka():
            logger.error("Failed to connect to Kafka. Exiting.")
            return

        if not self.connect_influxdb():
            logger.error("Failed to connect to InfluxDB. Exiting.")
            return

        try:
            logger.info("Waiting for messages...")

            for message in self.consumer:
                self.message_count += 1

                # Transform the message
                processed_data = self.transform_message(message.value)

                if processed_data:
                    # Output processed data
                    self.output_processed_data(processed_data)
                else:
                    logger.warning(f"Failed to process message {self.message_count}")

                # Log processing rate every 10 messages
                if self.message_count % 10 == 0:
                    elapsed = time.time() - self.start_time
                    rate = self.message_count / elapsed
                    logger.info(f"Processed {self.message_count} messages ({rate:.2f} msg/sec)")

        except KeyboardInterrupt:
            logger.info("Shutdown requested by user")
        except Exception as e:
            logger.error(f"Processor error: {e}")
        finally:
            if self.consumer:
                self.consumer.close()
            if self.influx_client:
                self.influx_client.close()
            logger.info("Data Processor stopped")

if __name__ == "__main__":
    processor = DataProcessor(window_size=10)  # 10-message rolling window
    processor.run()