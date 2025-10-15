#!/usr/bin/env python3
"""
Conveyor Line Speed Data Producer for Kubernetes
Generates realistic conveyor belt speed data (0.0-0.3 m/s)
Publishes to Kafka topic 'conveyor-speed'
Based on CA1 producer with environment-driven configuration
"""

import json
import time
import random
import os
from datetime import datetime, timezone
from kafka import KafkaProducer
from kafka.errors import KafkaError
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configuration from environment variables
KAFKA_BROKER = os.environ.get('KAFKA_BROKER', 'kafka-service:9092')
KAFKA_TOPIC = os.environ.get('KAFKA_TOPIC', 'conveyor-speed')
CONVEYOR_ID = os.environ.get('CONVEYOR_ID', 'line_1')

# Speed parameters (meters/second) - from CA1
MIN_SPEED = 0.0
MAX_SPEED = 0.3
NORMAL_SPEED_MIN = 0.15
NORMAL_SPEED_MAX = 0.25
SPEED_VARIATION = 0.02  # ±0.02 m/s variation

class ConveyorState:
    """Manages conveyor belt operational states"""
    STOPPED = "stopped"
    STARTING = "starting"
    RUNNING = "running"
    STOPPING = "stopping"
    MAINTENANCE = "maintenance"

class ConveyorProducer:
    def __init__(self):
        self.producer = None
        self.current_speed = 0.0
        self.state = ConveyorState.STOPPED
        self.state_timer = 0
        self.target_speed = 0.0

    def connect_kafka(self):
        """Initialize Kafka producer connection with retries"""
        max_retries = 10
        retry_delay = 5

        for attempt in range(max_retries):
            try:
                logger.info(f"Connecting to Kafka: {KAFKA_BROKER} (attempt {attempt + 1})")
                self.producer = KafkaProducer(
                    bootstrap_servers=[KAFKA_BROKER],
                    value_serializer=lambda v: json.dumps(v).encode('utf-8'),
                    acks='all',
                    retries=3,
                    retry_backoff_ms=1000
                )
                logger.info(f"✅ Connected to Kafka broker: {KAFKA_BROKER}")
                return True
            except Exception as e:
                logger.error(f"❌ Failed to connect to Kafka (attempt {attempt + 1}): {e}")
                if attempt < max_retries - 1:
                    logger.info(f"Retrying in {retry_delay} seconds...")
                    time.sleep(retry_delay)
                else:
                    logger.error("Max retries reached. Unable to connect to Kafka.")
                    return False

    def generate_realistic_speed(self):
        """Generate realistic conveyor speed based on current state - from CA1"""
        if self.state == ConveyorState.STOPPED:
            self.current_speed = 0.0
            if random.random() < 0.05:  # 5% chance to start
                self.state = ConveyorState.STARTING
                self.target_speed = random.uniform(NORMAL_SPEED_MIN, NORMAL_SPEED_MAX)
                self.state_timer = random.randint(3, 8)
                logger.info(f"Conveyor starting up, target speed: {self.target_speed:.3f} m/s")

        elif self.state == ConveyorState.STARTING:
            speed_increment = self.target_speed / self.state_timer
            self.current_speed = min(self.current_speed + speed_increment, self.target_speed)
            self.state_timer -= 1
            if self.state_timer <= 0:
                self.state = ConveyorState.RUNNING
                logger.info("Conveyor reached running speed")

        elif self.state == ConveyorState.RUNNING:
            variation = random.uniform(-SPEED_VARIATION, SPEED_VARIATION)
            self.current_speed = max(MIN_SPEED, min(MAX_SPEED, self.current_speed + variation))
            if random.random() < 0.01:  # 1% chance to stop
                self.state = ConveyorState.STOPPING
                self.state_timer = random.randint(2, 5)
                logger.info("Conveyor stopping")

        elif self.state == ConveyorState.STOPPING:
            speed_decrement = self.current_speed / self.state_timer
            self.current_speed = max(0.0, self.current_speed - speed_decrement)
            self.state_timer -= 1
            if self.state_timer <= 0:
                self.state = ConveyorState.STOPPED
                self.current_speed = 0.0
                logger.info("Conveyor stopped")

        # Ensure speed stays within bounds
        self.current_speed = max(MIN_SPEED, min(MAX_SPEED, self.current_speed))

    def create_message(self):
        """Create JSON message with conveyor data - enhanced for K8s"""
        timestamp = datetime.now(timezone.utc).isoformat()

        message = {
            "timestamp": timestamp,
            "conveyor_id": CONVEYOR_ID,
            "speed_ms": round(self.current_speed, 3),  # meters/second
            "state": self.state,
            "metadata": {
                "location": "Factory_Floor_A",
                "sensor_id": "SPEED_01",
                "unit": "m/s",
                "range_min": MIN_SPEED,
                "range_max": MAX_SPEED,
                "pod_name": os.environ.get('HOSTNAME', 'unknown'),
                "kafka_broker": KAFKA_BROKER
            }
        }
        return message

    def publish_message(self, message):
        """Publish message to Kafka topic"""
        try:
            future = self.producer.send(KAFKA_TOPIC, value=message)
            record_metadata = future.get(timeout=10)

            # Log every message for visibility
            log_msg = f"[{message['timestamp']}] Speed: {message['speed_ms']:.3f} m/s | State: {message['state']} | Pod: {message['metadata']['pod_name']}"
            logger.info(log_msg)
            return True

        except KafkaError as e:
            logger.error(f"Failed to publish message: {e}")
            return False
        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            return False

    def run(self):
        """Main producer loop"""
        logger.info("🚀 Starting Conveyor Speed Producer for CA2")
        logger.info(f"Target: {KAFKA_TOPIC} @ {KAFKA_BROKER}")
        logger.info(f"Speed range: {MIN_SPEED}-{MAX_SPEED} m/s")
        logger.info(f"Conveyor ID: {CONVEYOR_ID}")

        if not self.connect_kafka():
            logger.error("Failed to connect to Kafka. Exiting.")
            return

        try:
            message_count = 0
            while True:
                self.generate_realistic_speed()
                message = self.create_message()

                if self.publish_message(message):
                    message_count += 1

                # Log summary every 60 messages (1 minute)
                if message_count % 60 == 0:
                    logger.info(f"📊 Published {message_count} messages total")

                time.sleep(1.0)  # 1 Hz sampling rate

        except KeyboardInterrupt:
            logger.info("🛑 Shutdown requested by user")
        except Exception as e:
            logger.error(f"❌ Producer error: {e}")
        finally:
            if self.producer:
                self.producer.close()
            logger.info("✅ Producer stopped")

if __name__ == "__main__":
    producer = ConveyorProducer()
    producer.run()