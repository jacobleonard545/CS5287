#!/usr/bin/env python3
"""
Simple Kafka Producer for testing
Sends sensor data messages to Kafka topic
"""
import json
import time
import random
from datetime import datetime
from kafka import KafkaProducer

def create_sensor_data():
    """Generate sample sensor data"""
    return {
        "sensor_id": f"sensor-{random.randint(1, 10):03d}",
        "temperature": round(random.uniform(18.0, 35.0), 2),
        "humidity": round(random.uniform(30.0, 80.0), 2),
        "pressure": round(random.uniform(980.0, 1020.0), 2),
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }

def main():
    # Kafka configuration
    kafka_servers = ['10.0.1.162:9092']  # Kafka VM private IP
    topic = 'sensor-data'
    
    try:
        # Create producer
        producer = KafkaProducer(
            bootstrap_servers=kafka_servers,
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            key_serializer=lambda k: str(k).encode('utf-8') if k else None
        )
        
        print(f"Connected to Kafka at {kafka_servers}")
        print(f"Sending messages to topic: {topic}")
        
        message_count = 0
        while True:
            # Generate and send message
            data = create_sensor_data()
            key = data['sensor_id']
            
            producer.send(topic, key=key, value=data)
            message_count += 1
            
            print(f"Sent message {message_count}: {data}")
            
            # Send every 5 seconds
            time.sleep(5)
            
    except KeyboardInterrupt:
        print(f"\nShutting down after sending {message_count} messages")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        if 'producer' in locals():
            producer.close()

if __name__ == "__main__":
    main()