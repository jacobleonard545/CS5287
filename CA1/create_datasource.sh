#!/bin/bash
# Create InfluxDB datasource in Grafana

echo "🔧 Creating InfluxDB datasource in Grafana..."

# Wait for Grafana to be ready
echo "Waiting for Grafana to be ready..."
for i in {1..10}; do
  if curl -s "http://3.128.171.44:3000/api/health" | grep -q "ok"; then
    echo "✅ Grafana is ready"
    break
  else
    echo "Attempt $i: Waiting for Grafana..."
    sleep 5
  fi
done

# Create InfluxDB datasource
echo "Creating InfluxDB datasource..."
RESPONSE=$(curl -s -u admin:admin -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "name": "InfluxDB-ConveyorData",
    "type": "influxdb",
    "url": "http://10.0.1.220:8086",
    "access": "proxy",
    "isDefault": true,
    "jsonData": {
      "version": "Flux",
      "organization": "CA1",
      "defaultBucket": "conveyor_data",
      "tlsSkipVerify": true
    },
    "secureJsonData": {
      "token": "ca1-admin-token"
    }
  }' \
  http://3.128.171.44:3000/api/datasources)

echo "Response: $RESPONSE"

if echo "$RESPONSE" | grep -q '"id":\|"message":"data source with the same name already exists"'; then
  echo "✅ Datasource created successfully!"

  # Get the datasource UID
  sleep 2
  DATASOURCE_UID=$(curl -s -u admin:admin "http://3.128.171.44:3000/api/datasources" | jq -r '.[] | select(.name=="InfluxDB-ConveyorData") | .uid' 2>/dev/null)

  if [[ -n "$DATASOURCE_UID" && "$DATASOURCE_UID" != "null" ]]; then
    echo "✅ Datasource UID: $DATASOURCE_UID"
  else
    echo "⚠️ Could not retrieve datasource UID"
  fi
else
  echo "❌ Failed to create datasource"
  echo "Error: $RESPONSE"
fi

echo "🌐 Access Grafana at: http://3.128.171.44:3000"
echo "🔐 Login: admin / admin"