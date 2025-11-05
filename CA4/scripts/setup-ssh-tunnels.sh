#!/bin/bash
set -e

echo "=== CA4: Setting Up SSH Tunnels to AWS ===="

CLOUD_IP="3.148.242.194"
SSH_KEY="$HOME/.ssh/ca4-key"

# Kill any existing tunnels
echo "Cleaning up existing SSH tunnels..."
pkill -f "ssh.*$CLOUD_IP" 2>/dev/null || true
sleep 2

# Establish SSH tunnels for all services
echo "Establishing SSH tunnels..."
echo "  Local 9092 → Cloud Kafka 9092"
echo "  Local 8086 → Cloud InfluxDB 8086"
echo "  Local 3000 → Cloud Grafana 3000"
echo "  Local 8001 → Cloud Processor Metrics 8000"

ssh -i "$SSH_KEY" \
    -o StrictHostKeyChecking=no \
    -o ServerAliveInterval=60 \
    -o ServerAliveCountMax=3 \
    -L 9092:localhost:9092 \
    -L 8086:localhost:8086 \
    -L 3000:localhost:3000 \
    -L 8001:localhost:8000 \
    -N \
    -f \
    ubuntu@$CLOUD_IP

# Wait for tunnels to establish
sleep 3

# Verify tunnels
echo ""
echo "Verifying SSH tunnels..."
if ps aux | grep -v grep | grep "ssh.*$CLOUD_IP" > /dev/null; then
    echo "✓ SSH tunnels established successfully"
    echo ""
    echo "Port Mappings:"
    echo "  localhost:9092  → AWS Kafka"
    echo "  localhost:8086  → AWS InfluxDB (HTTPS)"
    echo "  localhost:3000  → AWS Grafana"
    echo "  localhost:8001  → AWS Processor Metrics"
    echo ""
    echo "To terminate tunnels: pkill -f 'ssh.*$CLOUD_IP'"
else
    echo "✗ Failed to establish SSH tunnels"
    exit 1
fi
