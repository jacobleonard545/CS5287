#!/bin/bash
# Simple test script to import the dashboard with correct UID

GRAFANA_IP="3.142.197.121"
DATASOURCE_UID="aeytlovthbqiof"
BUCKET="conveyor_data"

echo "Creating dashboard with UID: $DATASOURCE_UID"

# Create a minimal dashboard based on the provided JSON
cat > /tmp/test_dashboard.json << EOF
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
            "query": "from(bucket: \"$BUCKET\")\n  |> range(start: -5m)\n  |> filter(fn: (r) => r._measurement == \"conveyor_speed\")\n  |> filter(fn: (r) => r._field == \"rolling_avg\")\n  |> drop(columns: [\"alert_level\", \"state\"])\n  |> aggregateWindow(every: 1s, fn: mean, createEmpty: false)",
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
            "query": "from(bucket: \"$BUCKET\")\n  |> range(start: -5m)\n  |> filter(fn: (r) => r._measurement == \"conveyor_speed\")\n  |> filter(fn: (r) => r._field == \"speed_ms\")\n  |> drop(columns: [\"alert_level\", \"state\"])\n  |> aggregateWindow(every: 1s, fn: mean, createEmpty: false)",
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

# Import dashboard
echo "Importing dashboard..."
RESPONSE=$(curl -s -u admin:admin -X POST \
  -H "Content-Type: application/json" \
  -d @/tmp/test_dashboard.json \
  "http://$GRAFANA_IP:3000/api/dashboards/db")

if echo "$RESPONSE" | grep -q '"status":"success"'; then
  echo "✅ Dashboard imported successfully!"
  DASHBOARD_URL=$(echo "$RESPONSE" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
  DASHBOARD_UID=$(echo "$RESPONSE" | grep -o '"uid":"[^"]*"' | cut -d'"' -f4)
  echo "Dashboard URL: http://$GRAFANA_IP:3000$DASHBOARD_URL"
  echo "Dashboard UID: $DASHBOARD_UID"
else
  echo "❌ Dashboard import failed"
  echo "Response: $RESPONSE"
fi

rm -f /tmp/test_dashboard.json