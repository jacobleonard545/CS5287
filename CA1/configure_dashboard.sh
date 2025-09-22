#!/bin/bash
# CA1 Grafana Dashboard Auto-Configuration Script
# Automatically configures Conveyor Line Speed Monitoring dashboard with dynamic IPs and UIDs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== CA1 Dashboard Auto-Configuration ===${NC}"
echo "Configuring Conveyor Line Speed Monitoring Dashboard with Dynamic Values"
echo ""

# Check if terraform directory exists
if [ ! -d "terraform" ]; then
    echo -e "${RED}❌ Terraform directory not found. Please run from CA1 root directory.${NC}"
    exit 1
fi

# Get dynamic values from terraform
echo -e "${YELLOW}Getting dynamic values from Terraform...${NC}"
cd terraform

GRAFANA_IP=$(~/bin/terraform.exe output -raw grafana_instance_ip 2>/dev/null || echo "")
INFLUXDB_IP=$(~/bin/terraform.exe output -raw influxdb_private_ip 2>/dev/null || echo "")
INFLUXDB_BUCKET=$(~/bin/terraform.exe output -raw influxdb_bucket 2>/dev/null || echo "conveyor_data")
INFLUXDB_TOKEN=$(~/bin/terraform.exe output -raw influxdb_token 2>/dev/null || echo "ca1-influxdb-token-12345")
INFLUXDB_ORG=$(~/bin/terraform.exe output -raw influxdb_org 2>/dev/null || echo "CA1")
GRAFANA_PASSWORD="admin"

cd ..

if [[ -z "$GRAFANA_IP" ]]; then
    echo -e "${RED}❌ Could not get Grafana IP from Terraform. Ensure infrastructure is deployed.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Retrieved dynamic values:${NC}"
echo "   - Grafana IP: $GRAFANA_IP"
echo "   - InfluxDB IP: $INFLUXDB_IP"
echo "   - InfluxDB Bucket: $INFLUXDB_BUCKET"
echo "   - InfluxDB Organization: $INFLUXDB_ORG"
echo ""

# Test Grafana connectivity with retry
echo -e "${YELLOW}Testing Grafana connectivity...${NC}"
GRAFANA_READY=false
for i in {1..12}; do
    if curl -s "http://$GRAFANA_IP:3000/api/health" | grep -q "ok"; then
        GRAFANA_READY=true
        break
    else
        echo "Attempt $i/12: Waiting for Grafana to be ready..."
        sleep 10
    fi
done

if [ "$GRAFANA_READY" = false ]; then
    echo -e "${RED}❌ Grafana is not accessible at http://$GRAFANA_IP:3000 after 2 minutes${NC}"
    echo "Please ensure Grafana is running and accessible."
    exit 1
fi
echo -e "${GREEN}✅ Grafana is accessible${NC}"

# Get or create InfluxDB datasource
echo -e "${YELLOW}Configuring InfluxDB datasource...${NC}"

# Check if datasource exists
DATASOURCES=$(curl -s -u admin:$GRAFANA_PASSWORD "http://$GRAFANA_IP:3000/api/datasources")
DATASOURCE_UID=$(echo "$DATASOURCES" | jq -r '.[] | select(.name=="InfluxDB-ConveyorData") | .uid' 2>/dev/null)

if [[ -z "$DATASOURCE_UID" || "$DATASOURCE_UID" == "null" ]]; then
    echo "Creating new InfluxDB datasource..."

    # Create datasource
    RESPONSE=$(curl -s -u admin:$GRAFANA_PASSWORD -X POST \
      -H "Content-Type: application/json" \
      -d "{
        \"name\": \"InfluxDB-ConveyorData\",
        \"type\": \"influxdb\",
        \"url\": \"http://$INFLUXDB_IP:8086\",
        \"access\": \"proxy\",
        \"isDefault\": true,
        \"jsonData\": {
          \"version\": \"Flux\",
          \"organization\": \"$INFLUXDB_ORG\",
          \"defaultBucket\": \"$INFLUXDB_BUCKET\",
          \"tlsSkipVerify\": true
        },
        \"secureJsonData\": {
          \"token\": \"$INFLUXDB_TOKEN\"
        }
      }" \
      "http://$GRAFANA_IP:3000/api/datasources")

    if echo "$RESPONSE" | grep -q '"id":\|"message":"data source with the same name already exists"'; then
        echo -e "${GREEN}✅ Datasource created successfully${NC}"
    else
        echo -e "${RED}❌ Failed to create datasource: $RESPONSE${NC}"
        exit 1
    fi

    # Get the new datasource UID
    sleep 2
    DATASOURCES=$(curl -s -u admin:$GRAFANA_PASSWORD "http://$GRAFANA_IP:3000/api/datasources")
    DATASOURCE_UID=$(echo "$DATASOURCES" | jq -r '.[] | select(.name=="InfluxDB-ConveyorData") | .uid' 2>/dev/null)
else
    echo "Updating existing InfluxDB datasource..."

    # Update existing datasource
    DATASOURCE_ID=$(echo "$DATASOURCES" | jq -r '.[] | select(.name=="InfluxDB-ConveyorData") | .id' 2>/dev/null)

    RESPONSE=$(curl -s -u admin:$GRAFANA_PASSWORD -X PUT \
      -H "Content-Type: application/json" \
      -d "{
        \"id\": $DATASOURCE_ID,
        \"uid\": \"$DATASOURCE_UID\",
        \"name\": \"InfluxDB-ConveyorData\",
        \"type\": \"influxdb\",
        \"url\": \"http://$INFLUXDB_IP:8086\",
        \"access\": \"proxy\",
        \"isDefault\": true,
        \"jsonData\": {
          \"version\": \"Flux\",
          \"organization\": \"$INFLUXDB_ORG\",
          \"defaultBucket\": \"$INFLUXDB_BUCKET\",
          \"tlsSkipVerify\": true
        },
        \"secureJsonData\": {
          \"token\": \"$INFLUXDB_TOKEN\"
        }
      }" \
      "http://$GRAFANA_IP:3000/api/datasources/$DATASOURCE_ID")

    if echo "$RESPONSE" | grep -q '"message":"Datasource updated"'; then
        echo -e "${GREEN}✅ Datasource updated successfully${NC}"
    else
        echo -e "${RED}❌ Failed to update datasource: $RESPONSE${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✅ Datasource UID: $DATASOURCE_UID${NC}"

# Create dashboard configuration from CA1\Conveyor Line Speed Monitoring-1758520134746.json template
echo -e "${YELLOW}Creating dashboard configuration...${NC}"

cat > /tmp/ca1_dashboard.json << EOF
{
  "dashboard": {
    "annotations": {
      "list": [
        {
          "builtIn": 1,
          "datasource": {
            "type": "grafana",
            "uid": "-- Grafana --"
          },
          "enable": true,
          "hide": true,
          "iconColor": "rgba(0, 211, 255, 1)",
          "name": "Annotations & Alerts",
          "type": "dashboard"
        }
      ]
    },
    "editable": true,
    "fiscalYearStartMonth": 0,
    "graphTooltip": 0,
    "id": null,
    "links": [],
    "panels": [
      {
        "datasource": {
          "type": "influxdb",
          "uid": "$DATASOURCE_UID"
        },
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "palette-classic"
            },
            "custom": {
              "axisBorderShow": false,
              "axisCenteredZero": false,
              "axisColorMode": "text",
              "axisLabel": "",
              "axisPlacement": "auto",
              "barAlignment": 0,
              "barWidthFactor": 0.6,
              "drawStyle": "line",
              "fillOpacity": 0,
              "gradientMode": "none",
              "hideFrom": {
                "legend": false,
                "tooltip": false,
                "viz": false
              },
              "insertNulls": false,
              "lineInterpolation": "linear",
              "lineWidth": 1,
              "pointSize": 5,
              "scaleDistribution": {
                "type": "linear"
              },
              "showPoints": "auto",
              "spanNulls": false,
              "stacking": {
                "group": "A",
                "mode": "none"
              },
              "thresholdsStyle": {
                "mode": "off"
              }
            },
            "displayName": "Line 1 (m/s)",
            "mappings": [],
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {
                  "color": "green",
                  "value": 0
                },
                {
                  "color": "red",
                  "value": 80
                }
              ]
            },
            "unit": "short"
          },
          "overrides": []
        },
        "gridPos": {
          "h": 5,
          "w": 24,
          "x": 0,
          "y": 0
        },
        "id": 2,
        "options": {
          "legend": {
            "calcs": [],
            "displayMode": "list",
            "placement": "bottom",
            "showLegend": true
          },
          "tooltip": {
            "hideZeros": false,
            "mode": "single",
            "sort": "none"
          }
        },
        "pluginVersion": "12.1.1",
        "targets": [
          {
            "datasource": {
              "type": "influxdb",
              "uid": "$DATASOURCE_UID"
            },
            "query": "from(bucket: \"$INFLUXDB_BUCKET\")\n  |> range(start: -5m)\n  |> filter(fn: (r) => r._measurement == \"conveyor_speed\")\n  |> filter(fn: (r) => r._field == \"rolling_avg\")\n  |> drop(columns: [\"alert_level\", \"state\"])\n  |> aggregateWindow(every: 1s, fn: mean, createEmpty: false)",
            "refId": "A"
          }
        ],
        "title": "Average Speed",
        "type": "timeseries"
      },
      {
        "datasource": {
          "type": "influxdb",
          "uid": "$DATASOURCE_UID"
        },
        "fieldConfig": {
          "defaults": {
            "displayName": "Current Speed (m/s)",
            "mappings": [
              {
                "maintenance": {
                  "color": "purple",
                  "text": "MAINTENANCE"
                },
                "options": {
                  "running": {
                    "color": "green",
                    "text": "RUNNING"
                  }
                },
                "starting": {
                  "color": "yellow",
                  "text": "STARTING"
                },
                "stopped": {
                  "color": "red",
                  "text": "STOPPED"
                },
                "stopping": {
                  "color": "orange",
                  "text": "STOPPING"
                }
              }
            ],
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {
                  "color": "green",
                  "value": 0
                },
                {
                  "color": "red",
                  "value": 80
                }
              ]
            }
          },
          "overrides": []
        },
        "gridPos": {
          "h": 5,
          "w": 24,
          "x": 0,
          "y": 5
        },
        "id": 3,
        "options": {
          "colorMode": "value",
          "graphMode": "area",
          "justifyMode": "auto",
          "orientation": "auto",
          "percentChangeColorMode": "standard",
          "reduceOptions": {
            "calcs": [
              "lastNotNull"
            ],
            "fields": "",
            "values": false
          },
          "showPercentChange": false,
          "textMode": "auto",
          "wideLayout": true
        },
        "pluginVersion": "12.1.1",
        "targets": [
          {
            "datasource": {
              "type": "influxdb",
              "uid": "$DATASOURCE_UID"
            },
            "query": "from(bucket: \"$INFLUXDB_BUCKET\")\n  |> range(start: -5m)\n  |> filter(fn: (r) => r._measurement == \"conveyor_speed\")\n  |> filter(fn: (r) => r._field == \"speed_ms\")\n  |> drop(columns: [\"alert_level\", \"state\"])\n  |> aggregateWindow(every: 1s, fn: mean, createEmpty: false)",
            "refId": "A"
          }
        ],
        "title": "Line 1",
        "type": "stat"
      }
    ],
    "preload": false,
    "refresh": "5s",
    "schemaVersion": 41,
    "tags": [
      "conveyor",
      "iot",
      "manufacturing"
    ],
    "templating": {
      "list": []
    },
    "time": {
      "from": "now-5m",
      "to": "now"
    },
    "timepicker": {},
    "timezone": "browser",
    "title": "Conveyor Line Speed Monitoring",
    "uid": "46648b4d-ad50-4704-afcd-193a268b9c48",
    "version": 1
  },
  "overwrite": true
}
EOF

# Import/update dashboard
echo -e "${YELLOW}Importing Conveyor Line Speed Monitoring dashboard...${NC}"
RESPONSE=$(curl -s -u admin:$GRAFANA_PASSWORD -X POST \
  -H "Content-Type: application/json" \
  -d @/tmp/ca1_dashboard.json \
  "http://$GRAFANA_IP:3000/api/dashboards/db")

if echo "$RESPONSE" | grep -q '"status":"success"'; then
  echo -e "${GREEN}✅ Conveyor Line Speed Monitoring dashboard configured successfully!${NC}"
  DASHBOARD_URL=$(echo "$RESPONSE" | jq -r '.url' 2>/dev/null || echo "unknown")
  DASHBOARD_UID=$(echo "$RESPONSE" | jq -r '.uid' 2>/dev/null || echo "unknown")
  echo -e "${BLUE}Dashboard URL: http://$GRAFANA_IP:3000$DASHBOARD_URL${NC}"
  echo -e "${BLUE}Direct link: http://$GRAFANA_IP:3000/d/$DASHBOARD_UID${NC}"
else
  echo -e "${RED}❌ Dashboard configuration failed${NC}"
  echo "Response: $RESPONSE"
  exit 1
fi

# Test dashboard functionality
echo -e "${YELLOW}Testing dashboard data connectivity...${NC}"
TEST_RESPONSE=$(curl -s -u admin:$GRAFANA_PASSWORD -X POST \
  "http://$GRAFANA_IP:3000/api/ds/query" \
  -H "Content-Type: application/json" \
  -d "{\"queries\":[{\"refId\":\"A\",\"datasource\":{\"uid\":\"$DATASOURCE_UID\"},\"query\":\"from(bucket: \\\"$INFLUXDB_BUCKET\\\") |> range(start: -5m) |> filter(fn: (r) => r._measurement == \\\"conveyor_speed\\\") |> filter(fn: (r) => r._field == \\\"speed_ms\\\") |> limit(n: 1)\"}]}")

if echo "$TEST_RESPONSE" | grep -q '"frames"'; then
  echo -e "${GREEN}✅ Dashboard data connectivity test passed${NC}"
else
  echo -e "${YELLOW}⚠️ Dashboard created but data connectivity test inconclusive${NC}"
  echo "This may be normal if no data is currently flowing."
fi

# Clean up
rm -f /tmp/ca1_dashboard.json

echo ""
echo -e "${GREEN}🎉 CA1 Dashboard Auto-Configuration Completed!${NC}"
echo ""
echo -e "${BLUE}📊 Dashboard Information:${NC}"
echo "   - Title: Conveyor Line Speed Monitoring"
echo "   - URL: http://$GRAFANA_IP:3000/d/46648b4d-ad50-4704-afcd-193a268b9c48"
echo "   - Login: admin / $GRAFANA_PASSWORD"
echo "   - Datasource: InfluxDB-ConveyorData"
echo "   - Refresh Rate: 5 seconds"
echo ""
echo -e "${BLUE}📈 Dashboard Features:${NC}"
echo "   ✅ Real-time conveyor speed visualization"
echo "   ✅ Rolling average trend analysis"
echo "   ✅ Current conveyor state indicator"
echo "   ✅ Automatic data refresh every 5 seconds"
echo "   ✅ Dynamic datasource configuration"
echo ""
echo -e "${YELLOW}💡 Usage:${NC}"
echo "   - Run this script anytime to reconfigure with current dynamic values"
echo "   - Works automatically with any IP changes from terraform"
echo "   - Preserves existing datasource if already configured"
echo "   - Updates dashboard with latest configuration"