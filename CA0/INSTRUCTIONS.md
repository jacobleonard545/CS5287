# Deployment Instructions - Kafka Data Pipeline

## Prerequisites

### Local Machine Requirements
- AWS CLI v2 installed and configured
- SSH client available
- Git (to clone the repository)
- Web browser for accessing management interfaces

### AWS Account Setup
1. **AWS Account**: Active AWS account with appropriate permissions
2. **AWS CLI Configuration**:
   ```bash
   aws configure
   # Enter your AWS Access Key ID
   # Enter your AWS Secret Access Key  
   # Default region: us-east-2
   # Default output format: json
   ```
3. **Verify AWS Connection**:
   ```bash
   aws sts get-caller-identity
   ```

## Step 1: Clone Repository and Prepare

```bash
# Clone the project repository
git clone https://github.com/jacobleonard545/kafka-project.git
cd kafka-project/CA0

# Make scripts executable
chmod +x aws-infrastructure.sh
chmod +x user-data.sh
```

## Step 2: Deploy AWS Infrastructure

### 2.1 Create Infrastructure
```bash
# Deploy VPC, subnets, security groups, and EC2 instances
./aws-infrastructure.sh
```

**Expected Output:**
- VPC created with CIDR 10.0.0.0/16
- Public subnet created (10.0.1.0/24)
- Security group with proper firewall rules
- 4 EC2 instances launched
- SSH key pair generated (`kafka-pipeline-key.pem`)

### 2.2 Wait for Instance Initialization
```bash
# Wait 3-5 minutes for user-data script to complete
# Monitor instance status
aws ec2 describe-instances --region us-east-2 --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' --output table
```

### 2.3 Retrieve Instance Information
```bash
# Get instance details and save IPs
aws ec2 describe-instances --region us-east-2 --filters "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],PublicIpAddress,PrivateIpAddress]' --output table > instance-ips.txt

# Display the results
cat instance-ips.txt
```

## Step 3: Upload Application Files

### 3.1 Prepare Files for Upload
```bash
# Create deployment package
mkdir deployment-files
cp kafka-compose.yml deployment-files/
cp mongodb-compose.yml deployment-files/
cp processor-compose.yml deployment-files/
cp producer-compose.yml deployment-files/
cp init-mongo.js deployment-files/
cp -r processor deployment-files/
cp -r producer deployment-files/
```

### 3.2 Upload to Each VM

**Replace `<IP-ADDRESS>` with actual public IP addresses from instance-ips.txt**

```bash
# Upload to Kafka VM
scp -i kafka-pipeline-key.pem -r deployment-files/* ubuntu@<KAFKA-VM-IP>:/opt/kafka-pipeline/

# Upload to MongoDB VM  
scp -i kafka-pipeline-key.pem -r deployment-files/* ubuntu@<MONGODB-VM-IP>:/opt/kafka-pipeline/

# Upload to Processor VM
scp -i kafka-pipeline-key.pem -r deployment-files/* ubuntu@<PROCESSOR-VM-IP>:/opt/kafka-pipeline/

# Upload to Producer VM
scp -i kafka-pipeline-key.pem -r deployment-files/* ubuntu@<PRODUCER-VM-IP>:/opt/kafka-pipeline/
```

## Step 4: Deploy Services

### 4.1 Deploy Kafka Services (First)
```bash
# SSH to Kafka VM
ssh -i kafka-pipeline-key.pem ubuntu@<KAFKA-VM-IP>

# Start Kafka and ZooKeeper
cd /opt/kafka-pipeline
docker-compose -f kafka-compose.yml up -d

# Verify services are running
docker ps
docker logs zookeeper
docker logs kafka-broker
docker logs kafka-ui

# Wait for Kafka to be fully ready (2-3 minutes)
docker exec kafka-broker kafka-topics --bootstrap-server localhost:9092 --list

# Exit SSH session
exit
```

### 4.2 Deploy MongoDB Services (Second)
```bash
# SSH to MongoDB VM
ssh -i kafka-pipeline-key.pem ubuntu@<MONGODB-VM-IP>

# Start MongoDB
cd /opt/kafka-pipeline
docker-compose -f mongodb-compose.yml up -d

# Verify MongoDB is running
docker ps
docker logs mongodb-server
docker logs mongo-express

# Test MongoDB connection
docker exec mongodb-server mongosh --eval "db.adminCommand('ping')"

# Exit SSH session
exit
```

### 4.3 Build and Deploy Processor (Third)
```bash
# SSH to Processor VM
ssh -i kafka-pipeline-key.pem ubuntu@<PROCESSOR-VM-IP>

cd /opt/kafka-pipeline

# Build the processor image
docker build -t kafka-processor:latest processor/

# Update processor-compose.yml with correct Kafka and MongoDB IPs
sed -i 's/kafka:29092/<KAFKA-PRIVATE-IP>:9092/g' processor-compose.yml
sed -i 's/mongodb-server:27017/<MONGODB-PRIVATE-IP>:27017/g' processor-compose.yml

# Start the processor
docker-compose -f processor-compose.yml up -d

# Verify processor is running
docker ps
docker logs kafka-processor

# Exit SSH session
exit
```

### 4.4 Build and Deploy Producer (Fourth)
```bash
# SSH to Producer VM
ssh -i kafka-pipeline-key.pem ubuntu@<PRODUCER-VM-IP>

cd /opt/kafka-pipeline

# Build the producer image
docker build -t kafka-producer:latest producer/

# Update producer-compose.yml with correct Kafka IP
sed -i 's/kafka:29092/<KAFKA-PRIVATE-IP>:9092/g' producer-compose.yml

# Start the producer
docker-compose -f producer-compose.yml up -d

# Verify producer is running
docker ps
docker logs kafka-producer

# Exit SSH session
exit
```

## Step 5: Test the Data Pipeline

### 5.1 Access Management Interfaces

**Kafka UI:**
```bash
# Open in browser
http://<KAFKA-VM-PUBLIC-IP>:8080
```

**Mongo Express:**
```bash
# Open in browser  
http://<MONGODB-VM-PUBLIC-IP>:8081
# Login: admin / admin123
```

### 5.2 Create Test Topic
```bash
# SSH to Kafka VM
ssh -i kafka-pipeline-key.pem ubuntu@<KAFKA-VM-IP>

# Create test topic
docker exec kafka-broker kafka-topics --bootstrap-server localhost:9092 --create --topic sensor-data --partitions 3 --replication-factor 1

# List topics to verify
docker exec kafka-broker kafka-topics --bootstrap-server localhost:9092 --list

exit
```

### 5.3 Verify Data Flow

**Check Producer is Sending Data:**
```bash
# SSH to Producer VM
ssh -i kafka-pipeline-key.pem ubuntu@<PRODUCER-VM-IP>

# Check producer logs
docker logs kafka-producer

# Should see messages like: "Sent message to sensor-data"
exit
```

**Check Kafka is Receiving Messages:**
```bash
# SSH to Kafka VM
ssh -i kafka-pipeline-key.pem ubuntu@<KAFKA-VM-IP>

# Consume messages to verify
docker exec kafka-broker kafka-console-consumer --bootstrap-server localhost:9092 --topic sensor-data --from-beginning --timeout-ms 10000

# Should see JSON sensor data messages
exit
```

**Check Processor is Processing:**
```bash
# SSH to Processor VM
ssh -i kafka-pipeline-key.pem ubuntu@<PROCESSOR-VM-IP>

# Check processor logs
docker logs kafka-processor

# Should see processing messages
exit
```

**Check MongoDB has Data:**
```bash
# SSH to MongoDB VM
ssh -i kafka-pipeline-key.pem ubuntu@<MONGODB-VM-IP>

# Query MongoDB
docker exec mongodb-server mongosh --eval "use sensordata; db.processed_data.find().limit(5).pretty()"

# Should see processed sensor data documents
exit
```

### 5.4 Visual Verification

1. **Kafka UI (`http://<KAFKA-VM-PUBLIC-IP>:8080`)**:
   - Navigate to Topics → sensor-data
   - Verify message count is increasing
   - Check consumer group lag

2. **Mongo Express (`http://<MONGODB-VM-PUBLIC-IP>:8081`)**:
   - Navigate to sensordata database
   - Check processed_data collection
   - Verify documents are being inserted

## Step 6: Demo Preparation

### 6.1 Create Demo Script
```bash
# On your local machine, create demo.sh
cat > demo.sh << 'EOF'
#!/bin/bash
echo "=== Kafka Data Pipeline Demo ==="
echo "1. Kafka UI: http://<KAFKA-VM-PUBLIC-IP>:8080"
echo "2. MongoDB UI: http://<MONGODB-VM-PUBLIC-IP>:8081"
echo "3. Producer Status:"
ssh -i kafka-pipeline-key.pem ubuntu@<PRODUCER-VM-IP> 'docker logs kafka-producer --tail 5'
echo "4. Recent MongoDB Data:"
ssh -i kafka-pipeline-key.pem ubuntu@<MONGODB-VM-IP> 'docker exec mongodb-server mongosh --quiet --eval "use sensordata; db.processed_data.find().limit(3).pretty()"'
EOF

chmod +x demo.sh
```

### 6.2 Demo Video Preparation

**Demo Flow (1-2 minutes):**
1. Show Kafka UI with active topics and messages
2. Show Mongo Express with data being inserted
3. Display live logs showing data flow
4. Explain the architecture: Producer → Kafka → Processor → MongoDB

## Troubleshooting

### Common Issues

**Container Won't Start:**
```bash
# Check logs
docker logs <container-name>
# Check disk space
df -h
# Check Docker service
sudo systemctl status docker
```

**Network Connectivity Issues:**
```bash
# Test internal connectivity
telnet <private-ip> <port>
# Check security groups in AWS console
# Verify UFW status: sudo ufw status
```

**Data Not Flowing:**
```bash
# Restart services in order
docker-compose -f kafka-compose.yml restart
docker-compose -f processor-compose.yml restart
docker-compose -f producer-compose.yml restart
```

## Cleanup

### Remove AWS Resources
```bash
# Get instance IDs
aws ec2 describe-instances --region us-east-2 --query 'Reservations[*].Instances[*].InstanceId' --output text

# Terminate instances
aws ec2 terminate-instances --instance-ids <instance-ids> --region us-east-2

# Delete other resources (VPC, security groups, etc.)
# Or use AWS Console for complete cleanup
```

## Success Criteria

✅ **Infrastructure**: 4 VMs running in AWS us-east-2  
✅ **Services**: All containers running and healthy  
✅ **Data Flow**: Producer → Kafka → Processor → MongoDB  
✅ **Monitoring**: Management UIs accessible and showing data  
✅ **Security**: SSH key-only access, firewall configured  
✅ **Documentation**: Network diagram and configuration tables complete  

## Assignment Deliverables Checklist

- [x] VPC with proper subnet configuration
- [x] 4 VMs with specified sizes and Ubuntu 22.04 LTS
- [x] Security hardening (SSH keys, firewall, fail2ban)
- [x] Complete data pipeline functionality
- [x] Management interfaces accessible
- [x] Network diagram documentation
- [x] Configuration table with versions
- [x] Demo-ready environment

**Estimated Total Deployment Time: 15-20 minutes**  
**Demo Preparation Time: 5 minutes**