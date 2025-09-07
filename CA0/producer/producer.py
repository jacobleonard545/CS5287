#!/usr/bin/env python3

import json
import logging
import os
import random
import time
from datetime import datetime, timezone
from typing import Dict, Any
import pandas as pd
from kafka import KafkaProducer
from pythonjsonlogger import jsonlogger

# Configure logging
log_format = "%(asctime)s %(levelname)s %(name)s %(message)s"
logging.basicConfig(
    level=logging.INFO,
    format=log_format,
    handlers=[
        logging.FileHandler('/app/logs/producer.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class SensorDataProducer:
    def __init__(self):
        self.bootstrap_servers = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')
        self.topic = os.getenv('KAFKA_TOPIC', 'sensor-data')
        self.producer_interval = int(os.getenv('PRODUCER_INTERVAL', '5'))
        self.sensor_count = int(os.getenv('SENSOR_COUNT', '10'))
        self.producer_type = os.getenv('PRODUCER_TYPE', 'realtime')
        self.replay_file = os.getenv('REPLAY_FILE', '/app/data/historical_data.csv')
        
        # Initialize Kafka producer
        self.producer = KafkaProducer(
            bootstrap_servers=self.bootstrap_servers.split(','),
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            key_serializer=lambda k: k.encode('utf-8') if k else None,
            retries=3,
            retry_backoff_ms=1000
        )
        
        logger.info(f"Initialized producer for topic: {self.topic}")
        logger.info(f"Producer type: {self.producer_type}")

    def generate_sensor_data(self) -> Dict[str, Any]:
        """Generate realistic sensor data"""
        sensor_id = f"SENSOR_{random.randint(1, self.sensor_count):03d}"
        
        # Simulate different sensor types
        sensor_types = ['temperature', 'humidity', 'pressure', 'motion', 'light']
        sensor_type = random.choice(sensor_types)
        
        base_values = {
            'temperature': (15.0, 35.0),  # Celsius
            'humidity': (30.0, 80.0),     # Percentage
            'pressure': (980.0, 1050.0),  # hPa
            'motion': (0, 1),             # Binary
            'light': (0.0, 1000.0)       # Lux
        }
        
        min_val, max_val = base_values[sensor_type]
        
        if sensor_type == 'motion':
            value = random.choice([0, 1])
        else:
            value = round(random.uniform(min_val, max_val), 2)
        
        # Add some anomalies occasionally (5% chance)
        is_anomaly = random.random() < 0.05
        if is_anomaly and sensor_type != 'motion':
            value *= random.choice([0.5, 2.0])  # Extreme low or high values
        
        data = {
            'sensor_id': sensor_id,
            'sensor_type': sensor_type,
            'value': value,
            'unit': self._get_unit(sensor_type),
            'timestamp': datetime.now(timezone.utc).isoformat(),
            'location': {
                'building': f"Building_{random.choice(['A', 'B', 'C'])}",
                'floor': random.randint(1, 5),
                'room': f"Room_{random.randint(101, 599)}"
            },
            'quality': random.choice(['excellent', 'good', 'fair', 'poor']),
            'is_anomaly': is_anomaly,
            'battery_level': round(random.uniform(10.0, 100.0), 1),
            'signal_strength': random.randint(-90, -30)
        }
        
        return data

    def _get_unit(self, sensor_type: str) -> str:
        """Get unit for sensor type"""
        units = {
            'temperature': '°C',
            'humidity': '%',
            'pressure': 'hPa',
            'motion': 'bool',
            'light': 'lux'
        }
        return units.get(sensor_type, '')

    def produce_realtime_data(self):
        """Produce real-time sensor data"""
        logger.info("Starting real-time data production")
        
        try:
            while True:
                data = self.generate_sensor_data()
                
                # Send to Kafka
                future = self.producer.send(
                    self.topic,
                    key=data['sensor_id'],
                    value=data
                )
                
                # Optional: wait for confirmation
                try:
                    record_metadata = future.get(timeout=10)
                    logger.debug(f"Sent to partition {record_metadata.partition} at offset {record_metadata.offset}")
                except Exception as e:
                    logger.error(f"Failed to send message: {e}")
                
                logger.info(f"Produced: {data['sensor_id']} - {data['sensor_type']}={data['value']}{data['unit']}")
                time.sleep(self.producer_interval)
                
        except KeyboardInterrupt:
            logger.info("Shutting down producer...")
        finally:
            self.producer.close()

    def produce_replay_data(self):
        """Replay historical data from CSV file"""
        logger.info(f"Starting data replay from: {self.replay_file}")
        
        try:
            # Create sample data if file doesn't exist
            if not os.path.exists(self.replay_file):
                self._create_sample_data()
            
            df = pd.read_csv(self.replay_file)
            logger.info(f"Loaded {len(df)} records from replay file")
            
            for _, row in df.iterrows():
                data = {
                    'sensor_id': row['sensor_id'],
                    'sensor_type': row['sensor_type'],
                    'value': row['value'],
                    'unit': row['unit'],
                    'timestamp': datetime.now(timezone.utc).isoformat(),  # Use current time
                    'original_timestamp': row['timestamp'],
                    'location': json.loads(row['location']) if 'location' in row else {},
                    'quality': row.get('quality', 'good'),
                    'is_anomaly': row.get('is_anomaly', False),
                    'replay': True
                }
                
                future = self.producer.send(
                    self.topic,
                    key=data['sensor_id'],
                    value=data
                )
                
                logger.info(f"Replayed: {data['sensor_id']} - {data['sensor_type']}={data['value']}")
                time.sleep(1)  # Faster replay
                
        except Exception as e:
            logger.error(f"Error in replay: {e}")
        finally:
            self.producer.close()

    def _create_sample_data(self):
        """Create sample historical data file"""
        logger.info("Creating sample historical data")
        
        data = []
        for i in range(100):
            sensor_data = self.generate_sensor_data()
            data.append({
                'sensor_id': sensor_data['sensor_id'],
                'sensor_type': sensor_data['sensor_type'],
                'value': sensor_data['value'],
                'unit': sensor_data['unit'],
                'timestamp': sensor_data['timestamp'],
                'location': json.dumps(sensor_data['location']),
                'quality': sensor_data['quality'],
                'is_anomaly': sensor_data['is_anomaly']
            })
        
        df = pd.DataFrame(data)
        os.makedirs(os.path.dirname(self.replay_file), exist_ok=True)
        df.to_csv(self.replay_file, index=False)
        logger.info(f"Created sample data file: {self.replay_file}")

def main():
    producer = SensorDataProducer()
    
    if producer.producer_type == 'replay':
        producer.produce_replay_data()
    else:
        producer.produce_realtime_data()

if __name__ == "__main__":
    main()