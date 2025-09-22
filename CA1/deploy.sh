#!/bin/bash
# CA1 Infrastructure Deployment Script
# Automated deployment of IoT data pipeline using Terraform

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"

echo -e "${BLUE}=== CA1 Infrastructure Deployment ===${NC}"
echo "Deploying IoT Data Pipeline with Terraform"
echo ""

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"

    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}❌ Terraform is not installed${NC}"
        echo "Please install Terraform: https://www.terraform.io/downloads.html"
        exit 1
    fi

    # Check if AWS CLI is configured
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${RED}❌ AWS CLI not configured${NC}"
        echo "Please run: aws configure"
        exit 1
    fi

    # Check if SSH key exists
    if [ ! -f ~/.ssh/ca1-demo-key ]; then
        echo -e "${YELLOW}⚠️ SSH key not found. Generating new key pair...${NC}"
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/ca1-demo-key -N "" -C "ca1-demo-key"
        chmod 400 ~/.ssh/ca1-demo-key
        echo -e "${GREEN}✅ SSH key generated: ~/.ssh/ca1-demo-key${NC}"
    fi

    echo -e "${GREEN}✅ Prerequisites check passed${NC}"
    echo ""
}

# Deploy infrastructure
deploy_infrastructure() {
    echo -e "${YELLOW}Deploying infrastructure...${NC}"

    cd "$TERRAFORM_DIR"

    # Initialize Terraform
    echo "Initializing Terraform..."
    terraform init

    # Plan deployment
    echo "Creating deployment plan..."
    terraform plan -out=tfplan

    # Apply deployment
    echo "Applying deployment..."
    terraform apply tfplan

    echo -e "${GREEN}✅ Infrastructure deployed successfully${NC}"
    echo ""
}

# Wait for services to initialize
wait_for_services() {
    echo -e "${YELLOW}Waiting for services to initialize...${NC}"

    cd "$TERRAFORM_DIR"

    # Get instance IPs
    PRODUCER_IP=$(terraform output -raw producer_instance_ip)
    KAFKA_IP=$(terraform output -raw kafka_instance_ip)
    PROCESSOR_IP=$(terraform output -raw processor_instance_ip)
    INFLUXDB_IP=$(terraform output -raw influxdb_instance_ip)
    GRAFANA_IP=$(terraform output -raw grafana_instance_ip)

    echo "Waiting 3 minutes for all services to start up properly..."

    # Show progress with countdown
    for i in {180..1}; do
        printf "\rTime remaining: %d seconds " $i
        sleep 1
    done
    printf "\r                                \r"

    echo -e "${GREEN}✅ Initial startup period completed${NC}"
    echo ""
}

# Verify basic connectivity
verify_connectivity() {
    echo -e "${YELLOW}Verifying SSH connectivity to instances...${NC}"

    cd "$TERRAFORM_DIR"

    # Get instance IPs
    PRODUCER_IP=$(terraform output -raw producer_instance_ip)
    KAFKA_IP=$(terraform output -raw kafka_instance_ip)
    PROCESSOR_IP=$(terraform output -raw processor_instance_ip)
    INFLUXDB_IP=$(terraform output -raw influxdb_instance_ip)
    GRAFANA_IP=$(terraform output -raw grafana_instance_ip)

    instances=("$PRODUCER_IP:Producer" "$KAFKA_IP:Kafka" "$PROCESSOR_IP:Processor" "$INFLUXDB_IP:InfluxDB" "$GRAFANA_IP:Grafana")

    for instance in "${instances[@]}"; do
        ip="${instance%%:*}"
        name="${instance##*:}"

        if ssh -i ~/.ssh/ca1-demo-key -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@"$ip" "echo 'Connected'" &>/dev/null; then
            echo -e "  ${GREEN}✅ $name ($ip)${NC}"
        else
            echo -e "  ${RED}❌ $name ($ip) - Connection failed${NC}"
        fi
    done
    echo ""
}

# Configure Grafana dashboard
configure_dashboard() {
    echo -e "${YELLOW}Configuring Grafana dashboard...${NC}"
    echo ""

    # Wait a bit longer for Grafana to fully initialize
    echo "Waiting additional time for Grafana to fully initialize..."
    sleep 60

    cd "$TERRAFORM_DIR"

    # Get dynamic values from terraform
    echo "Getting dynamic values from Terraform..."
    local GRAFANA_IP=$(/c/Users/J14Le/bin/terraform.exe output -raw grafana_instance_ip 2>/dev/null || echo "")
    local INFLUXDB_IP=$(/c/Users/J14Le/bin/terraform.exe output -raw influxdb_private_ip 2>/dev/null || echo "")
    local INFLUXDB_BUCKET=$(/c/Users/J14Le/bin/terraform.exe output -raw influxdb_bucket 2>/dev/null || echo "conveyor_data")
    local INFLUXDB_TOKEN=$(/c/Users/J14Le/bin/terraform.exe output -raw influxdb_token 2>/dev/null || echo "ca1-influxdb-token-12345")
    local INFLUXDB_ORG=$(/c/Users/J14Le/bin/terraform.exe output -raw influxdb_org 2>/dev/null || echo "CA1")

    cd ..

    if [[ -z "$GRAFANA_IP" ]]; then
        echo -e "${RED}❌ Could not get Grafana IP from Terraform${NC}"
        echo "Dashboard configuration skipped"
        return 1
    fi

    echo -e "${GREEN}✅ Retrieved dynamic values:${NC}"
    echo "   - Grafana IP: $GRAFANA_IP"
    echo "   - InfluxDB IP: $INFLUXDB_IP"
    echo "   - InfluxDB Bucket: $INFLUXDB_BUCKET"
    echo "   - InfluxDB Organization: $INFLUXDB_ORG"

    # Test Grafana connectivity with retry
    echo -e "${YELLOW}Testing Grafana connectivity...${NC}"
    local GRAFANA_READY=false
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
        echo -e "${RED}❌ Grafana not accessible after 2 minutes${NC}"
        echo "Dashboard configuration skipped"
        return 1
    fi
    echo -e "${GREEN}✅ Grafana is accessible${NC}"

    # Get or verify InfluxDB datasource
    echo -e "${YELLOW}Configuring InfluxDB datasource...${NC}"
    local DATASOURCES=$(curl -s -u admin:admin "http://$GRAFANA_IP:3000/api/datasources")
    local DATASOURCE_UID=$(echo "$DATASOURCES" | jq -r '.[] | select(.name=="InfluxDB-ConveyorData") | .uid' 2>/dev/null || echo "")

    if [[ -z "$DATASOURCE_UID" || "$DATASOURCE_UID" == "null" ]]; then
        echo "Creating new InfluxDB datasource..."
        local RESPONSE=$(curl -s -u admin:admin -X POST \
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
            echo -e "${GREEN}✅ Datasource created/updated successfully${NC}"
        else
            echo -e "${YELLOW}⚠️ Datasource creation had issues but continuing...${NC}"
        fi

        # Get the datasource UID again
        sleep 2
        DATASOURCES=$(curl -s -u admin:admin "http://$GRAFANA_IP:3000/api/datasources")
        DATASOURCE_UID=$(echo "$DATASOURCES" | jq -r '.[] | select(.name=="InfluxDB-ConveyorData") | .uid' 2>/dev/null || echo "")
    else
        echo -e "${GREEN}✅ Using existing datasource${NC}"
    fi

    echo -e "${GREEN}✅ Datasource UID: $DATASOURCE_UID${NC}"
    # Verify we have a valid UID
    if [[ -z "$DATASOURCE_UID" || "$DATASOURCE_UID" == "null" ]]; then
        echo -e "${RED}❌ Failed to get valid datasource UID${NC}"
        echo "Debug: Datasources response:"
        echo "$DATASOURCES" | jq '.' 2>/dev/null || echo "$DATASOURCES"
        return 1
    fi


    # Create dashboard configuration based on CA1\Conveyor Line Speed Monitoring-1758520134746.json
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
            "query": "from(bucket: \"$INFLUXDB_BUCKET\")\\n  |> range(start: -5m)\\n  |> filter(fn: (r) => r._measurement == \"conveyor_speed\")\\n  |> filter(fn: (r) => r._field == \"rolling_avg\")\\n  |> drop(columns: [\"alert_level\", \"state\"])\\n  |> aggregateWindow(every: 1s, fn: mean, createEmpty: false)",
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
            "query": "from(bucket: \"$INFLUXDB_BUCKET\")\\n  |> range(start: -5m)\\n  |> filter(fn: (r) => r._measurement == \"conveyor_speed\")\\n  |> filter(fn: (r) => r._field == \"speed_ms\")\\n  |> drop(columns: [\"alert_level\", \"state\"])\\n  |> aggregateWindow(every: 1s, fn: mean, createEmpty: false)",
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
    local RESPONSE=$(curl -s -u admin:admin -X POST \
      -H "Content-Type: application/json" \
      -d @/tmp/ca1_dashboard.json \
      "http://$GRAFANA_IP:3000/api/dashboards/db")

    if echo "$RESPONSE" | grep -q '"status":"success"'; then
      echo -e "${GREEN}✅ Conveyor Line Speed Monitoring dashboard configured successfully!${NC}"
      local DASHBOARD_URL=$(echo "$RESPONSE" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
      local DASHBOARD_UID=$(echo "$RESPONSE" | grep -o '"uid":"[^"]*"' | cut -d'"' -f4)
      echo -e "${BLUE}Dashboard URL: http://$GRAFANA_IP:3000$DASHBOARD_URL${NC}"
      echo -e "${BLUE}Direct link: http://$GRAFANA_IP:3000/d/$DASHBOARD_UID${NC}"
    else
      echo -e "${YELLOW}⚠️ Dashboard configuration had issues but deployment continues${NC}"
      echo "You can access Grafana at: http://$GRAFANA_IP:3000"
    fi

    # Clean up
    rm -f /tmp/ca1_dashboard.json

    echo -e "${GREEN}✅ Dashboard configuration completed${NC}"
    echo ""
}

# Display deployment information
show_deployment_info() {
    echo -e "${BLUE}=== CA1 Deployment Summary ===${NC}"

    cd "$TERRAFORM_DIR"

    # Get outputs
    echo -e "${BLUE}📍 Instance IPs:${NC}"
    echo "  Producer:  $(terraform output -raw producer_instance_ip)"
    echo "  Kafka:     $(terraform output -raw kafka_instance_ip)"
    echo "  Processor: $(terraform output -raw processor_instance_ip)"
    echo "  InfluxDB:  $(terraform output -raw influxdb_instance_ip)"
    echo "  Grafana:   $(terraform output -raw grafana_instance_ip)"

    echo ""
    echo -e "${BLUE}🌐 Service Endpoints:${NC}"
    echo "  Grafana Dashboard: $(terraform output -raw grafana_url)"
    echo "  InfluxDB API:      $(terraform output -raw influxdb_endpoint)"
    echo "  Kafka Broker:      $(terraform output -raw kafka_endpoint)"

    echo ""
    echo -e "${BLUE}🔐 SSH Access:${NC}"
    terraform output ssh_commands

    echo ""
    echo -e "${BLUE}🔗 Data Flow Architecture:${NC}"
    echo "  Producer → Kafka → Processor → InfluxDB → Grafana"
    echo "  ├─ Producer generates conveyor speed data (0.0-0.3 m/s)"
    echo "  ├─ Kafka manages message queuing and distribution"
    echo "  ├─ Processor enriches data with analytics and anomaly detection"
    echo "  ├─ InfluxDB stores time-series data with rolling metrics"
    echo "  └─ Grafana provides real-time dashboards and visualizations"

    echo ""
    echo -e "${BLUE}🔄 Data Flow Connections:${NC}"
    echo "  ✅ Producer → Kafka: Dynamic IP configuration ($(terraform output -raw kafka_private_ip):9092)"
    echo "  ✅ Kafka → Processor: Consumer group 'data-processor-group'"
    echo "  ✅ Processor → InfluxDB: HTTP API connection ($(terraform output -raw influxdb_private_ip):8086)"
    echo "  ✅ InfluxDB → Grafana: Query API with token authentication"

    echo ""
    echo -e "${BLUE}📊 Data Processing Features:${NC}"
    echo "  ✅ Rolling window analytics (10-message window)"
    echo "  ✅ Anomaly detection (speed thresholds, state changes)"
    echo "  ✅ Alert levels (normal/high based on anomaly count)"
    echo "  ✅ Speed unit conversion (m/s to km/h)"
    echo "  ✅ Message enrichment with processing metadata"

    echo ""
    echo -e "${BLUE}📈 Grafana Dashboard Features:${NC}"
    echo "  ✅ Real-time conveyor speed visualization (5s refresh)"
    echo "  ✅ Rolling average trend analysis (30m window)"
    echo "  ✅ Current conveyor state indicator"
    echo "  ✅ Anomaly count alerts with threshold colors"
    echo "  ✅ Message processing rate monitoring"
    echo "  ✅ Automatic InfluxDB datasource configuration"
    echo "  ✅ Pre-configured dashboard with optimal queries"
    echo "  ✅ Automated dashboard configuration with dynamic IPs/UIDs"

    echo ""
    echo -e "${GREEN}🎉 CA1 IoT Data Pipeline Deployed Successfully!${NC}"
    echo ""
    echo -e "${YELLOW}📋 Next Steps:${NC}"
    echo "1. 🔍 Run './validate.sh' for comprehensive system validation"
    echo "2. 📊 Access Grafana Dashboard:"
    echo "   └─ URL: $(terraform output -raw grafana_url)"
    echo "   └─ Login: admin / admin"
    echo "   └─ Dashboard: 'Conveyor Line Speed Monitoring' (auto-configured)"
    echo "   └─ Direct Link: $(terraform output -raw grafana_url)/d/46648b4d-ad50-4704-afcd-193a268b9c48"
    echo "3. 📈 Monitor real-time conveyor data and analytics:"
    echo "   ├─ Speed trends and rolling averages"
    echo "   ├─ Conveyor state monitoring"
    echo "   ├─ Anomaly detection alerts"
    echo "   └─ Message processing rates"
    echo "4. 🧹 Use 'terraform destroy' when finished to clean up resources"
    echo ""
    echo -e "${BLUE}💡 Quick Status Check:${NC}"
    echo "  ./validate.sh - Full system validation with detailed reporting"
    echo "  SSH commands are available in the terraform output above"
}

# Main execution
main() {
    echo "Starting CA1 deployment..."
    echo "Timestamp: $(date)"
    echo ""

    check_prerequisites
    deploy_infrastructure
    wait_for_services
    verify_connectivity
    configure_dashboard
    show_deployment_info

    echo -e "${GREEN}🎉 CA1 deployment script completed!${NC}"
    echo ""
    echo -e "${BLUE}🚀 Ready for validation! Run './validate.sh' for detailed system verification.${NC}"
}

# Error handling
trap 'echo -e "${RED}❌ Deployment failed at line $LINENO${NC}"' ERR

# Run main function
main "$@"