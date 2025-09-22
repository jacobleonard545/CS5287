# CA1 - IoT Data Pipeline Infrastructure as Code

Automated deployment of a complete IoT data pipeline using Terraform on AWS.

## Architecture

```
Conveyor Producer → Kafka Hub → Data Processor → InfluxDB → Grafana Dashboard
     (t2.micro)    (t2.micro)    (t2.micro)     (t2.micro)    (t2.micro)
```

## Quick Start

### 1. Prerequisites
- AWS CLI configured (`aws configure`)
- Terraform installed
- Bash shell (Git Bash on Windows)

### 2. Deploy Infrastructure
```bash
./deploy.sh
```

### 3. Validate Deployment
```bash
./validate.sh
```

### 4. Access Dashboard
- Grafana: `http://<grafana-ip>:3000`
- Login: `admin` / `admin`

### 5. Cleanup (when done)
```bash
./destroy.sh
```

## Scripts Overview

### `deploy.sh`
- **Purpose**: Complete infrastructure deployment
- **Features**:
  - Prerequisites checking
  - SSH key generation
  - Terraform initialization and deployment
  - Output display with URLs and IPs
- **Runtime**: ~5-7 minutes

### `validate.sh`
- **Purpose**: End-to-end system validation
- **Checks**:
  - Instance connectivity
  - Service status (Producer, Kafka, Processor, InfluxDB, Grafana)
  - Data flow verification
  - Web interface accessibility
- **Runtime**: ~1-2 minutes

### `destroy.sh`
- **Purpose**: Safe infrastructure cleanup
- **Features**:
  - Resource confirmation
  - Complete resource destruction
  - Cost optimization
  - Optional local file cleanup
- **Runtime**: ~3-5 minutes

## Components

### CA1-conveyor-producer
- **Function**: Simulates realistic conveyor belt speed data
- **Output**: Speed values 0.0-0.3 m/s with state transitions
- **Format**: `[timestamp] Speed: X.XXX m/s | State: running`

### CA1-kafka-hub
- **Function**: Message broker using Kafka KRaft mode
- **Topic**: `conveyor-speed`
- **Memory**: Optimized for t2.micro (300MB limit)

### CA1-data-processor
- **Function**: Real-time data processing and analytics
- **Features**: Rolling averages, anomaly detection
- **Output**: Processed metrics to InfluxDB

### CA1-influx-db
- **Function**: Time-series database storage
- **Bucket**: `conveyor_data`
- **Retention**: Configurable (default: 30 days)

### CA1-grafana-dash
- **Function**: Real-time monitoring dashboard
- **Features**: Speed trends, alerts, state visualization
- **Access**: Web interface on port 3000

## Configuration

### Key Files
- `terraform/terraform.tfvars` - Main configuration
- `terraform/modules/compute/user_data/` - Service setup scripts
- `terraform/modules/networking/` - VPC and security groups
- `terraform/modules/security/` - Security group rules

### Customization
1. **Speed Range**: Modify `MIN_SPEED`/`MAX_SPEED` in producer script
2. **Memory Limits**: Adjust `kafka_memory_limit` in tfvars
3. **Retention**: Update InfluxDB retention policies
4. **Monitoring**: Customize Grafana dashboards

## Security

- **Network**: VPC with public subnet
- **Access**: SSH key-based authentication
- **Ports**: Minimal exposure (SSH, HTTP, service-specific)
- **Security Groups**: Principle of least privilege

## Monitoring

### Health Checks
```bash
# Producer status
ssh -i ~/.ssh/ca1-demo-key ubuntu@<producer-ip> /home/ubuntu/check_producer.sh

# Kafka status
ssh -i ~/.ssh/ca1-demo-key ubuntu@<kafka-ip> /home/ubuntu/check_kafka.sh

# InfluxDB status
ssh -i ~/.ssh/ca1-demo-key ubuntu@<influxdb-ip> /home/ubuntu/check_influxdb.sh
```

### Log Locations
- Producer: `/home/ubuntu/producer.log`
- Kafka: `docker logs kafka`
- Processor: `/home/ubuntu/processor.log`
- InfluxDB: `docker logs influxdb`
- Grafana: `docker logs grafana`

## Troubleshooting

### Common Issues

1. **Services not starting**
   - Wait 2-3 minutes for initialization
   - Check logs for specific errors
   - Verify security group rules

2. **No data in Grafana**
   - Confirm producer is sending messages
   - Check Kafka topic has messages
   - Verify processor is consuming data
   - Ensure InfluxDB connection

3. **Connection timeouts**
   - Verify SSH key permissions (400)
   - Check AWS security groups
   - Confirm instance public IPs

### Manual Fixes
```bash
# Restart producer
ssh -i ~/.ssh/ca1-demo-key ubuntu@<producer-ip> "sudo pkill python3; nohup python3 /home/ubuntu/conveyor_producer.py > /home/ubuntu/producer.log 2>&1 &"

# Restart Kafka
ssh -i ~/.ssh/ca1-demo-key ubuntu@<kafka-ip> "sudo docker restart kafka"

# Check Kafka topics
ssh -i ~/.ssh/ca1-demo-key ubuntu@<kafka-ip> "sudo docker exec kafka kafka-topics.sh --bootstrap-server localhost:9092 --list"
```

## Cost Optimization

- **Instance Type**: t2.micro (AWS Free Tier eligible)
- **Runtime**: ~$0.50/hour for all 5 instances
- **Daily Cost**: ~$12/day if left running
- **Recommendation**: Use `./destroy.sh` when not needed

## Development

### Adding New Components
1. Create module in `terraform/modules/`
2. Add user_data script for service setup
3. Update main.tf to include new module
4. Add validation logic to `validate.sh`

### Testing Changes
1. `terraform plan` to preview changes
2. `terraform apply` to deploy updates
3. Use `validate.sh` to verify functionality

## Support

For issues or questions:
1. Check logs using validation script
2. Review Terraform outputs for IPs/URLs
3. Verify AWS console for resource status
4. Use manual troubleshooting commands above