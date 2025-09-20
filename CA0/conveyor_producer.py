#!/usr/bin/env python3
"""
Conveyor Line Speed Data Producer
Generates realistic conveyor belt speed data (0.0-0.3 m/s)
Publishes to Kafka topic 'conveyor-speed'
"""

import json
import time
import random
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

# Configuration
KAFKA_BROKER = '18.217.38.119:9092'  # kafka-hub instance
KAFKA_TOPIC = 'conveyor-speed'
CONVEYOR_ID = 'line_1'

# Speed parameters (meters/second)
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
        """Initialize Kafka producer connection"""
        try:
            self.producer = KafkaProducer(
                bootstrap_servers=[KAFKA_BROKER],
                value_serializer=lambda v: json.dumps(v).encode('utf-8'),
                acks='all',
                retries=3,
                retry_backoff_ms=1000
            )
            logger.info(f"Connected to Kafka broker: {KAFKA_BROKER}")
            return True
        except Exception as e:
            logger.error(f"Failed to connect to Kafka: {e}")
            return False

    def generate_realistic_speed(self):
        """Generate realistic conveyor speed based on current state"""
        if self.state == ConveyorState.STOPPED:
            # Stopped - no movement
            self.current_speed = 0.0

            # Randomly start up
            if random.random() < 0.05:  # 5% chance to start
                self.state = ConveyorState.STARTING
                self.target_speed = random.uniform(NORMAL_SPEED_MIN, NORMAL_SPEED_MAX)
                self.state_timer = random.randint(3, 8)  # 3-8 seconds to start
                logger.info(f"Conveyor starting up, target speed: {self.target_speed:.3f} m/s")

        elif self.state == ConveyorState.STARTING:
            # Gradually ramp up speed
            speed_increment = self.target_speed / self.state_timer
            self.current_speed = min(self.current_speed + speed_increment, self.target_speed)
            self.state_timer -= 1

            if self.state_timer <= 0:
                self.state = ConveyorState.RUNNING
                logger.info("Conveyor reached running speed")

        elif self.state == ConveyorState.RUNNING:
            # Normal operation with small variations
            variation = random.uniform(-SPEED_VARIATION, SPEED_VARIATION)
            self.current_speed = max(MIN_SPEED, min(MAX_SPEED, self.current_speed + variation))

            # Occasionally stop or go to maintenance
            if random.random() < 0.01:  # 1% chance to stop
                self.state = ConveyorState.STOPPING
                self.state_timer = random.randint(2, 5)
                logger.info("Conveyor stopping")
            elif random.random() < 0.005:  # 0.5% chance for maintenance
                self.state = ConveyorState.MAINTENANCE
                self.state_timer = random.randint(10, 30)
                logger.info("Conveyor entering maintenance mode")

        elif self.state == ConveyorState.STOPPING:
            # Gradually slow down
            speed_decrement = self.current_speed / self.state_timer
            self.current_speed = max(0.0, self.current_speed - speed_decrement)
            self.state_timer -= 1

            if self.state_timer <= 0:
                self.state = ConveyorState.STOPPED
                self.current_speed = 0.0
                logger.info("Conveyor stopped")

        elif self.state == ConveyorState.MAINTENANCE:
            # Maintenance - stopped
            self.current_speed = 0.0
            self.state_timer -= 1

            if self.state_timer <= 0:
                self.state = ConveyorState.STOPPED
                logger.info("Maintenance completed")

        # Ensure speed stays within bounds
        self.current_speed = max(MIN_SPEED, min(MAX_SPEED, self.current_speed))

    def create_message(self):
        """Create JSON message with conveyor data"""
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
                "range_max": MAX_SPEED
            }
        }

        return message

    def publish_message(self, message):
        """Publish message to Kafka topic"""
        try:
            future = self.producer.send(KAFKA_TOPIC, value=message)
            record_metadata = future.get(timeout=10)

            # Log to console and file
            log_msg = f"[{message['timestamp']}] Speed: {message['speed_ms']:.3f} m/s | State: {message['state']}"
            logger.info(log_msg)

            # Also write to local file for backup
            with open('/tmp/conveyor_data.jsonl', 'a') as f:
                f.write(json.dumps(message) + '\n')

            return True

        except KafkaError as e:
            logger.error(f"Failed to publish message: {e}")
            return False
        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            return False

    def run(self):
        """Main producer loop"""
        logger.info("Starting Conveyor Speed Producer")
        logger.info(f"Target: {KAFKA_TOPIC} @ {KAFKA_BROKER}")
        logger.info(f"Speed range: {MIN_SPEED}-{MAX_SPEED} m/s")

        if not self.connect_kafka():
            logger.error("Failed to connect to Kafka. Exiting.")
            return

        try:
            while True:
                # Generate realistic speed data
                self.generate_realistic_speed()

                # Create and publish message
                message = self.create_message()
                self.publish_message(message)

                # Wait 1 second (1 Hz sampling rate)
                time.sleep(1.0)

        except KeyboardInterrupt:
            logger.info("Shutdown requested by user")
        except Exception as e:
            logger.error(f"Producer error: {e}")
        finally:
            if self.producer:
                self.producer.close()
            logger.info("Producer stopped")

if __name__ == "__main__":
    producer = ConveyorProducer()
    producer.run()