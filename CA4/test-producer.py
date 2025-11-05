#!/usr/bin/env python3
"""
Simple test producer to validate Kafka connectivity via SSH tunnel
"""
import json
import time
from datetime import datetime, timezone
from kafka import KafkaProducer
from kafka.errors import KafkaError

# Connect to Kafka via SSH tunnel
KAFKA_BROKER = 'localhost:9092'  # Via SSH tunnel to AWS
KAFKA_TOPIC = 'conveyor-speed'

print(f"Connecting to Kafka at {KAFKA_BROKER}...")
try:
    producer = KafkaProducer(
        bootstrap_servers=[KAFKA_BROKER],
        value_serializer=lambda v: json.dumps(v).encode('utf-8'),
        acks='all',
        retries=3,
        max_in_flight_requests_per_connection=1
    )
    print("[OK] Connected to Kafka successfully!")

    # Send 5 test messages
    for i in range(5):
        message = {
            'timestamp': datetime.now(timezone.utc).isoformat(),
            'conveyor_id': 'test-producer',
            'speed': 0.15 + (i * 0.01),
            'state': 'running',
            'test_message': i + 1
        }

        future = producer.send(KAFKA_TOPIC, value=message)
        result = future.get(timeout=10)

        print(f"[OK] Message {i+1}/5 sent successfully")
        print(f"  Topic: {result.topic}, Partition: {result.partition}, Offset: {result.offset}")
        time.sleep(1)

    producer.flush()
    print("\n[OK] All test messages sent successfully!")
    print(f"[OK] Data flow validated: Local Producer -> SSH Tunnel -> AWS KRaft")

except Exception as e:
    print(f"[ERROR] Error: {e}")
    import traceback
    traceback.print_exc()
finally:
    if 'producer' in locals():
        producer.close()
