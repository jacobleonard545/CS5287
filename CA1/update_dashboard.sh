#!/bin/bash
# Update Grafana Dashboard with Conveyor Line Speed Monitoring configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Updating Grafana Dashboard ===${NC}"

# Get Grafana IP from terraform
cd terraform
GRAFANA_IP=$(~/bin/terraform.exe output -raw grafana_instance_ip)
INFLUXDB_BUCKET=$(~/bin/terraform.exe output -raw influxdb_bucket 2>/dev/null || echo "conveyor_data")

echo "Grafana IP: $GRAFANA_IP"
echo "InfluxDB Bucket: $INFLUXDB_BUCKET"

# Get datasource UID
echo -e "${YELLOW}Getting InfluxDB datasource UID...${NC}"
DATASOURCES=$(curl -s -u admin:admin "http://$GRAFANA_IP:3000/api/datasources")
DATASOURCE_UID=$(echo "$DATASOURCES" | jq -r '.[] | select(.name=="InfluxDB-ConveyorData") | .uid' 2>/dev/null)

if [[ -n "$DATASOURCE_UID" && "$DATASOURCE_UID" != "null" ]]; then
    echo -e "${GREEN}✅ Found datasource UID: $DATASOURCE_UID${NC}"
else
    echo -e "${RED}❌ Could not find InfluxDB datasource${NC}"
    exit 1
fi

# Create updated dashboard JSON
echo -e "${YELLOW}Creating dashboard configuration...${NC}"
cat > /tmp/dashboard_update.json << EOF
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
                "options": {
                  "running": {
                    "color": "green",
                    "text": "RUNNING"
                  },
                  "maintenance": {
                    "color": "purple",
                    "text": "MAINTENANCE"
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
                },
                "type": "value"
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
          "w": 11,
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
      },
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
            }
          },
          "overrides": []
        },
        "gridPos": {
          "h": 5,
          "w": 13,
          "x": 11,
          "y": 5
        },
        "id": 4,
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
        "title": "Line 1 Status",
        "type": "timeseries"
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
    "uid": "conveyor-line-monitoring",
    "version": 1
  },
  "overwrite": true
}
EOF

# Import/update dashboard
echo -e "${YELLOW}Importing Conveyor Line Speed Monitoring dashboard...${NC}"
RESPONSE=$(curl -s -u admin:admin -X POST \
  -H "Content-Type: application/json" \
  -d @/tmp/dashboard_update.json \
  "http://$GRAFANA_IP:3000/api/dashboards/db")

if echo "$RESPONSE" | grep -q '"status":"success"'; then
  echo -e "${GREEN}✅ Conveyor Line Speed Monitoring dashboard imported successfully!${NC}"
  DASHBOARD_URL=$(echo "$RESPONSE" | jq -r '.url' 2>/dev/null || echo "unknown")
  DASHBOARD_UID=$(echo "$RESPONSE" | jq -r '.uid' 2>/dev/null || echo "unknown")
  echo -e "${BLUE}Dashboard URL: http://$GRAFANA_IP:3000$DASHBOARD_URL${NC}"
  echo -e "${BLUE}Direct link: http://$GRAFANA_IP:3000/d/$DASHBOARD_UID${NC}"
else
  echo -e "${RED}❌ Dashboard import failed${NC}"
  echo "Response: $RESPONSE"
fi

# Clean up
rm -f /tmp/dashboard_update.json

echo -e "${GREEN}🎉 Dashboard update completed!${NC}"
echo -e "${BLUE}Access your dashboard at: http://$GRAFANA_IP:3000${NC}"
echo -e "${BLUE}Login: admin / admin${NC}"