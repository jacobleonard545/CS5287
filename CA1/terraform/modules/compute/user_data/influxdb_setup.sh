#!/bin/bash
# CA1 InfluxDB Setup Script
# Based on CA0-summary.md configuration

set -e
exec > >(tee /var/log/influxdb-setup.log) 2>&1

echo "$(date): Starting CA1 InfluxDB setup..."

# Update system
apt-get update -y

# Install Docker
echo "$(date): Installing Docker..."
apt-get install -y docker.io curl
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# Set hostname
hostnamectl set-hostname CA1-influx-db

# Create directories
echo "$(date): Creating InfluxDB directories..."
mkdir -p /app/influxdb
chown ubuntu:ubuntu /app/influxdb

# Wait for Docker to be fully ready
echo "$(date): Waiting for Docker to be ready..."
sleep 15

# Start InfluxDB with initialization
echo "$(date): Starting InfluxDB container..."
docker run -d --name influxdb \
  -p 8086:8086 \
  -v /app/influxdb:/var/lib/influxdb2 \
  -e DOCKER_INFLUXDB_INIT_MODE=setup \
  -e DOCKER_INFLUXDB_INIT_USERNAME=${influxdb_username} \
  -e DOCKER_INFLUXDB_INIT_PASSWORD=${influxdb_password} \
  -e DOCKER_INFLUXDB_INIT_ORG=${influxdb_org} \
  -e DOCKER_INFLUXDB_INIT_BUCKET=${influxdb_bucket} \
  -e DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=${influxdb_token} \
  --restart unless-stopped \
  influxdb:2.7

# Wait for InfluxDB to start
echo "$(date): Waiting for InfluxDB to start..."
sleep 45

# Verify InfluxDB is running
echo "$(date): Verifying InfluxDB container status..."
docker ps | grep influxdb

# Wait for InfluxDB to be fully ready
echo "$(date): Waiting for InfluxDB to be fully ready..."
sleep 30

# Test InfluxDB health
echo "$(date): Testing InfluxDB health..."
for i in {1..10}; do
  if curl -s http://localhost:8086/health | grep -q "ready"; then
    echo "✅ InfluxDB is healthy and ready!"
    break
  else
    echo "Attempt $i: InfluxDB not ready yet, waiting..."
    sleep 10
  fi
done

# Create validation scripts
cat > /home/ubuntu/check_influxdb.sh << 'EOF'
#!/bin/bash
echo "=== InfluxDB Container Status ==="
sudo docker ps | grep influxdb

echo ""
echo "=== InfluxDB Health ==="
curl -s http://localhost:8086/health | jq '.' 2>/dev/null || curl -s http://localhost:8086/health

echo ""
echo "=== InfluxDB Logs (last 20 lines) ==="
sudo docker logs influxdb --tail 20

echo ""
echo "=== Disk Usage ==="
df -h /app/influxdb

echo ""
echo "=== Port Status ==="
netstat -tlnp | grep 8086
EOF

cat > /home/ubuntu/test_influxdb.sh << 'EOF'
#!/bin/bash
echo "=== Testing InfluxDB Functionality ==="

# Test basic connectivity
echo "Testing InfluxDB health endpoint..."
curl -s http://localhost:8086/health

echo ""
echo "=== Testing Data Query ==="
echo "Querying recent conveyor data..."
curl -X POST \
  -H "Authorization: Token ${influxdb_token}" \
  -H "Content-type: application/vnd.flux" \
  "http://localhost:8086/api/v2/query?org=${influxdb_org}" \
  -d 'from(bucket:"${influxdb_bucket}") |> range(start: -5m) |> filter(fn: (r) => r._measurement == "conveyor_speed") |> limit(n: 5)'

echo ""
echo "=== Check Recent Data Count ==="
curl -X POST \
  -H "Authorization: Token ${influxdb_token}" \
  -H "Content-type: application/vnd.flux" \
  "http://localhost:8086/api/v2/query?org=${influxdb_org}" \
  -d 'from(bucket:"${influxdb_bucket}") |> range(start: -1h) |> filter(fn: (r) => r._measurement == "conveyor_speed") |> count()'
EOF

# Set permissions
chmod +x /home/ubuntu/check_influxdb.sh
chmod +x /home/ubuntu/test_influxdb.sh
chown ubuntu:ubuntu /home/ubuntu/check_influxdb.sh
chown ubuntu:ubuntu /home/ubuntu/test_influxdb.sh

# Create environment file for easy access
cat > /home/ubuntu/influxdb_env.sh << EOF
export INFLUXDB_URL="http://localhost:8086"
export INFLUXDB_TOKEN="${influxdb_token}"
export INFLUXDB_ORG="${influxdb_org}"
export INFLUXDB_BUCKET="${influxdb_bucket}"
EOF

chown ubuntu:ubuntu /home/ubuntu/influxdb_env.sh

echo "$(date): InfluxDB setup completed successfully!"
echo "$(date): Organization: ${influxdb_org}"
echo "$(date): Bucket: ${influxdb_bucket}"
echo "$(date): Token: ${influxdb_token}"
echo "$(date): Use 'sudo -u ubuntu /home/ubuntu/check_influxdb.sh' to check status"
echo "$(date): Use 'sudo -u ubuntu /home/ubuntu/test_influxdb.sh' to test functionality"