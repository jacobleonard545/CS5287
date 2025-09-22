#!/bin/bash
# CA1 Kafka KRaft Setup Script
# Based on CA0-summary.md optimizations for t2.micro memory constraints

set -e
exec > >(tee /var/log/kafka-setup.log) 2>&1

echo "$(date): Starting CA1 Kafka KRaft setup..."

# Update system
apt-get update -y

# Install Docker
echo "$(date): Installing Docker..."
apt-get install -y docker.io
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# Set hostname
hostnamectl set-hostname CA1-kafka-hub

# Generate valid base64 UUID for KRaft (based on CA0 working configuration)
echo "$(date): Generating valid KRaft cluster ID..."
CLUSTER_ID="MkU3OEVBNTcwNTJENDM2Qk"
echo "Using validated Cluster ID: $CLUSTER_ID"

# Get instance private IP
echo "$(date): Getting instance private IP..."
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
echo "Instance private IP: $PRIVATE_IP"

# Wait for Docker to be fully ready
echo "$(date): Waiting for Docker to be ready..."
sleep 15

# Start Kafka KRaft with exact CA0 working configuration for t2.micro
echo "$(date): Starting Kafka KRaft container with CA0-validated configuration..."
sudo docker run -d --name kafka \
  -p 9092:9092 \
  -e KAFKA_ENABLE_KRAFT=yes \
  -e KAFKA_CFG_PROCESS_ROLES=controller,broker \
  -e KAFKA_CFG_CONTROLLER_LISTENER_NAMES=CONTROLLER \
  -e KAFKA_CFG_LISTENERS=CONTROLLER://:9093,PLAINTEXT://:9092 \
  -e KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT \
  -e KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://$PRIVATE_IP:9092 \
  -e KAFKA_CFG_CONTROLLER_QUORUM_VOTERS=1@127.0.0.1:9093 \
  -e KAFKA_CFG_NODE_ID=1 \
  -e KAFKA_KRAFT_CLUSTER_ID=$CLUSTER_ID \
  -e KAFKA_HEAP_OPTS='${kafka_heap_opts}' \
  -e KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE=true \
  -e KAFKA_CFG_LOG_CLEANER_ENABLE=false \
  -e KAFKA_CFG_LOG_CLEANUP_POLICY=delete \
  -e KAFKA_CFG_LOG_RETENTION_HOURS=1 \
  -e KAFKA_CFG_LOG_SEGMENT_BYTES=1048576 \
  --memory=${kafka_memory_limit}m \
  --restart unless-stopped \
  bitnami/kafka:3.4

# Wait for Kafka to start
echo "$(date): Waiting for Kafka to start..."
sleep 30

# Verify Kafka is running
echo "$(date): Verifying Kafka container status..."
sudo docker ps | grep kafka

# Wait for Kafka to be fully ready and check logs
echo "$(date): Waiting for Kafka to be fully ready..."
sleep 45
echo "$(date): Checking Kafka startup logs..."
sudo docker logs kafka --tail 10

# Create validation scripts
cat > /home/ubuntu/check_kafka.sh << 'EOF'
#!/bin/bash
echo "=== Kafka Container Status ==="
sudo docker ps | grep kafka

echo ""
echo "=== Kafka Logs (last 20 lines) ==="
sudo docker logs kafka --tail 20

echo ""
echo "=== List Topics ==="
sudo docker exec kafka kafka-topics.sh --bootstrap-server localhost:9092 --list

echo ""
echo "=== Memory Usage ==="
free -h

echo ""
echo "=== Port Status ==="
netstat -tlnp | grep 9092
EOF

cat > /home/ubuntu/test_kafka.sh << 'EOF'
#!/bin/bash
echo "=== Testing Kafka Connectivity ==="

# Test if Kafka is accepting connections
echo "Testing port connectivity..."
timeout 5 bash -c 'cat < /dev/null > /dev/tcp/localhost/9092' && echo "✅ Port 9092 is open" || echo "❌ Port 9092 is not accessible"

echo ""
echo "=== Describe conveyor-speed topic ==="
sudo docker exec kafka kafka-topics.sh --describe --bootstrap-server localhost:9092 --topic conveyor-speed

echo ""
echo "=== Consume last 5 messages ==="
sudo docker exec kafka kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic conveyor-speed \
  --from-beginning \
  --max-messages 5 \
  --timeout-ms 10000
EOF

# Set permissions
chmod +x /home/ubuntu/check_kafka.sh
chmod +x /home/ubuntu/test_kafka.sh
chown ubuntu:ubuntu /home/ubuntu/check_kafka.sh
chown ubuntu:ubuntu /home/ubuntu/test_kafka.sh

# Log setup completion
echo "$(date): Kafka KRaft started with cluster ID: $CLUSTER_ID"
echo "$(date): Advertised listeners set to: $PRIVATE_IP:9092"
echo "$(date): Memory optimization: heap=${kafka_heap_opts}, container limit=${kafka_memory_limit}MB"
echo "$(date): Kafka setup completed successfully!"
echo "$(date): Use 'sudo -u ubuntu /home/ubuntu/check_kafka.sh' to check status"
echo "$(date): Use 'sudo -u ubuntu /home/ubuntu/test_kafka.sh' to test functionality"