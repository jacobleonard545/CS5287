#!/bin/bash
set -e

echo "=== CA4: Deploying Cloud Components to AWS ==="

CLOUD_IP="3.22.240.63"
SSH_KEY="$HOME/.ssh/ca4-key"

echo "Cloud Instance IP: $CLOUD_IP"

# Wait for SSH to be ready
echo "Waiting for SSH to be ready..."
max_attempts=30
attempt=0
while ! ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$CLOUD_IP "echo 'SSH ready'" 2>/dev/null; do
    attempt=$((attempt + 1))
    if [ $attempt -ge $max_attempts ]; then
        echo "ERROR: SSH not ready after $max_attempts attempts"
        exit 1
    fi
    echo "Attempt $attempt/$max_attempts..."
    sleep 10
done

echo "SSH is ready!"

# Copy Docker Compose files and configs
echo "Copying deployment files..."
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no CA4/docker-compose-cloud.yml ubuntu@$CLOUD_IP:~/docker-compose.yml
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no CA4/.env.cloud ubuntu@$CLOUD_IP:~/.env

# Generate TLS certificates on cloud instance
echo "Generating TLS certificates..."
ssh -i "$SSH_KEY" ubuntu@$CLOUD_IP << 'ENDSSH'
mkdir -p ~/tls-certs
cd ~/tls-certs

# Generate self-signed certificate
openssl genrsa -out tls.key 2048
openssl req -new -key tls.key -out tls.csr -subj "/C=US/ST=Tennessee/L=Nashville/O=VanderbiltU/OU=CS5287/CN=influxdb"
openssl x509 -req -days 365 -in tls.csr -signkey tls.key -out tls.crt

echo "TLS certificates generated"
ENDSSH

# Build processor image on cloud
echo "Building processor image..."
ssh -i "$SSH_KEY" ubuntu@$CLOUD_IP << 'ENDSSH'
# Create processor directory
mkdir -p ~/processor
cat > ~/processor/Dockerfile << 'EOF'
FROM python:3.11-slim
WORKDIR /app
RUN pip install --no-cache-dir kafka-python influxdb-client prometheus_client
COPY conveyor_processor.py .
RUN useradd -m -u 1000 processor && chown -R processor:processor /app
USER processor
CMD ["python", "conveyor_processor.py"]
EOF
ENDSSH

# Copy processor code
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no CA4/docker/processor/conveyor_processor.py ubuntu@$CLOUD_IP:~/processor/

# Build image
echo "Building Docker image..."
ssh -i "$SSH_KEY" ubuntu@$CLOUD_IP << 'ENDSSH'
cd ~/processor
sudo docker build -t j14le/conveyor-processor:ca3-metrics-tls .
ENDSSH

# Deploy with Docker Compose
echo "Deploying services with Docker Compose..."
ssh -i "$SSH_KEY" ubuntu@$CLOUD_IP << 'ENDSSH'
cd ~
sudo docker-compose down 2>/dev/null || true
sudo docker-compose up -d
echo "Waiting for services to start..."
sleep 30
sudo docker-compose ps
ENDSSH

echo ""
echo "=== Cloud Deployment Complete ==="
echo "Cloud Instance IP: $CLOUD_IP"
echo "SSH Command: ssh -i $SSH_KEY ubuntu@$CLOUD_IP"
echo ""
echo "Services running:"
echo "  - Kafka: $CLOUD_IP:9092"
echo "  - InfluxDB: https://$CLOUD_IP:8086"
echo "  - Grafana: http://$CLOUD_IP:3000"
echo "  - Processor Metrics: http://$CLOUD_IP:8000/metrics"
echo ""
echo "Next: Run './CA4/scripts/setup-ssh-tunnels.sh' to establish connectivity"
