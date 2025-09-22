#!/bin/bash
# CA1 Grafana Setup Script
# Based on CA0-summary.md with automated datasource configuration

set -e
exec > >(tee /var/log/grafana-setup.log) 2>&1

echo "$(date): Starting CA1 Grafana setup..."

# Update system
apt-get update -y

# Install Docker and curl
echo "$(date): Installing Docker and dependencies..."
apt-get install -y docker.io curl jq
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# Set hostname
hostnamectl set-hostname CA1-grafana-dash

# Create grafana data directory with correct ownership
echo "$(date): Creating Grafana directories..."
mkdir -p /app/grafana/data
chown -R 472:472 /app/grafana/data

# Wait for Docker to be fully ready
echo "$(date): Waiting for Docker to be ready..."
sleep 15

# Start Grafana container
echo "$(date): Starting Grafana container..."
docker run -d --name grafana \
  -p 3000:3000 \
  -v /app/grafana/data:/var/lib/grafana \
  -e GF_SECURITY_ADMIN_PASSWORD=${grafana_admin_password} \
  -e GF_USERS_ALLOW_SIGN_UP=false \
  --user 472:472 \
  --restart unless-stopped \
  grafana/grafana:latest

# Wait for Grafana to start
echo "$(date): Waiting for Grafana to start..."
sleep 45

# Verify Grafana is running
echo "$(date): Verifying Grafana container status..."
docker ps | grep grafana

# Wait for Grafana to be fully ready
echo "$(date): Waiting for Grafana to be fully ready..."
sleep 30

# Test Grafana health
echo "$(date): Testing Grafana health..."
for i in {1..10}; do
  if curl -s http://localhost:3000/api/health | grep -q "ok"; then
    echo "✅ Grafana is healthy and ready!"
    break
  else
    echo "Attempt $i: Grafana not ready yet, waiting..."
    sleep 10
  fi
done

# Configure InfluxDB datasource via API
echo "$(date): Configuring InfluxDB datasource..."
cat > /tmp/datasource.json << EOF
{
  "name": "InfluxDB-ConveyorData",
  "type": "influxdb",
  "url": "http://${influxdb_ip}:8086",
  "access": "proxy",
  "isDefault": true,
  "jsonData": {
    "version": "Flux",
    "organization": "${influxdb_org}",
    "defaultBucket": "${influxdb_bucket}",
    "tlsSkipVerify": true
  },
  "secureJsonData": {
    "token": "${influxdb_token}"
  }
}
EOF

# Create datasource (retry until Grafana is ready)
echo "$(date): Creating InfluxDB datasource..."
for i in {1..10}; do
  RESPONSE=$(curl -s -u admin:${grafana_admin_password} -X POST \
    -H "Content-Type: application/json" \
    -d @/tmp/datasource.json \
    http://localhost:3000/api/datasources)

  if echo "$RESPONSE" | grep -q '"id":\|"message":"data source with the same name already exists"'; then
    echo "✅ Datasource created successfully!"
    echo "Response: $RESPONSE"
    break
  else
    echo "Attempt $i: Waiting for Grafana API... Response: $RESPONSE"
    sleep 10
  fi
done

# Note: Dashboard will be configured after deployment using configure_dashboard.sh
echo "$(date): Basic Grafana setup completed. Dashboard will be configured via separate script."

# Create validation scripts
cat > /home/ubuntu/check_grafana.sh << 'EOF'
#!/bin/bash
echo "=== Grafana Container Status ==="
sudo docker ps | grep grafana

echo ""
echo "=== Grafana Health ==="
curl -s http://localhost:3000/api/health

echo ""
echo "=== Grafana Datasources ==="
curl -s -u admin:${grafana_admin_password} http://localhost:3000/api/datasources

echo ""
echo "=== Grafana Logs (last 20 lines) ==="
sudo docker logs grafana --tail 20

echo ""
echo "=== Port Status ==="
netstat -tlnp | grep 3000
EOF

cat > /home/ubuntu/test_grafana.sh << 'EOF'
#!/bin/bash
echo "=== Testing Grafana Dashboard ==="

echo "Testing Grafana web interface..."
curl -s http://localhost:3000/api/health

echo ""
echo "=== Testing Datasource Connection ==="
curl -s -u admin:${grafana_admin_password} \
  "http://localhost:3000/api/datasources/proxy/1/health"

echo ""
echo "=== Dashboard List ==="
curl -s -u admin:${grafana_admin_password} \
  "http://localhost:3000/api/search?query=conveyor"
EOF

# Set permissions
chmod +x /home/ubuntu/check_grafana.sh
chmod +x /home/ubuntu/test_grafana.sh
chown ubuntu:ubuntu /home/ubuntu/check_grafana.sh
chown ubuntu:ubuntu /home/ubuntu/test_grafana.sh

# Clean up temporary files
rm -f /tmp/datasource.json

echo "$(date): Grafana basic setup completed successfully!"
echo "$(date): Grafana URL: http://localhost:3000"
echo "$(date): Login: admin / admin"
echo "$(date): InfluxDB datasource configured for: ${influxdb_ip}:8086"
echo "$(date): Dashboard will be configured via configure_dashboard.sh script"
echo "$(date): Use 'sudo -u ubuntu /home/ubuntu/check_grafana.sh' to check status"
echo "$(date): Use 'sudo -u ubuntu /home/ubuntu/test_grafana.sh' to test functionality"