#!/usr/bin/env python3
"""
Simple Kafka Consumer to MongoDB
Consumes from Kafka and stores in MongoDB
"""
import json
import time
from kafka import KafkaConsumer
from pymongo import MongoClient
from datetime import datetime

def main():
    # Configuration
    kafka_servers = ['10.0.1.162:9092']
    mongo_uri = 'mongodb://admin:pipeline2023@10.0.1.160:27017/sensordata'
    topic = 'sensor-data'
    
    try:
        # Connect to MongoDB
        mongo_client = MongoClient(mongo_uri)
        db = mongo_client.sensordata
        collection = db.processed_data
        
        # Connect to Kafka
        consumer = KafkaConsumer(
            topic,
            bootstrap_servers=kafka_servers,
            value_deserializer=lambda m: json.loads(m.decode('utf-8')),
            group_id='simple-processor',
            auto_offset_reset='latest'
        )
        
        print(f"Connected to Kafka: {kafka_servers}")
        print(f"Connected to MongoDB: {mongo_uri}")
        print(f"Consuming from topic: {topic}")
        
        message_count = 0
        for message in consumer:
            data = message.value
            
            # Process and enrich data
            processed_data = {
                **data,
                'processed_at': datetime.utcnow().isoformat() + 'Z',
                'partition': message.partition,
                'offset': message.offset,
                'processed_by': 'simple-processor'
            }
            
            # Insert into MongoDB
            result = collection.insert_one(processed_data)
            message_count += 1
            
            print(f"Processed message {message_count}: {data['sensor_id']} -> MongoDB ({result.inserted_id})")
            
    except KeyboardInterrupt:
        print(f"\nShutting down after processing {message_count} messages")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        if 'consumer' in locals():
            consumer.close()
        if 'mongo_client' in locals():
            mongo_client.close()

if __name__ == "__main__":
    main()