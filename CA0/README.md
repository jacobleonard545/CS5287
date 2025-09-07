# Kafka Data Pipeline - CA0 Project

## VM Specifications

## Assignment-Compliant Deployment (Per Requirements: 3-4 VMs, ~2 vCPU, 4GB RAM)

| VM Name | Size | OS | vCPU | RAM | IP Address | Purpose |
|---------|------|----|------|-----|------------|---------|
| kafka-vm | t2.medium | Ubuntu 22.04 LTS | 2 | 4 GB | 10.0.1.10 | Kafka Broker + ZooKeeper + UI |
| mongodb-vm | t2.medium | Ubuntu 22.04 LTS | 2 | 4 GB | 10.0.1.11 | MongoDB + Mongo Express |
| processor-vm | t2.small | Ubuntu 22.04 LTS | 1 | 2 GB | 10.0.1.12 | Java Data Processor |
| producer-vm | t2.small | Ubuntu 22.04 LTS | 1 | 2 GB | 10.0.1.13 | Python Data Producer |

## Cost-Optimized Alternative (t2.micro - May Impact Performance)

| VM Name | Size | OS | vCPU | RAM | IP Address | Purpose |
|---------|------|----|------|-----|------------|---------|
| kafka-vm | t2.micro | Ubuntu 22.04 LTS | 1 | 1 GB | 10.0.1.10 | Kafka + ZooKeeper + UI |
| mongodb-vm | t2.micro | Ubuntu 22.04 LTS | 1 | 1 GB | 10.0.1.11 | MongoDB + Mongo Express |
| processor-vm | t2.micro | Ubuntu 22.04 LTS | 1 | 1 GB | 10.0.1.12 | Java Data Processor |
| producer-vm | t2.micro | Ubuntu 22.04 LTS | 1 | 1 GB | 10.0.1.13 | Python Data Producer |

## Image Tags and Version Numbers

### Container Images
| Component | Image | Version | Notes |
|-----------|-------|---------|-------|
| ZooKeeper | confluentinc/cp-zookeeper | 7.4.0 | Kafka coordination service |
| Kafka | confluentinc/cp-kafka | 7.4.0 | Message streaming platform |
| Kafka UI | provectuslabs/kafka-ui | latest | Web management interface |
| MongoDB | mongo | 6.0 | Document database |
| Mongo Express | mongo-express | latest | MongoDB web interface |
| Data Processor | kafka-processor | latest | Custom Java application |
| Data Producer | kafka-producer | latest | Custom Python application |

### System Software
| Software | Version | Purpose |
|----------|---------|---------|
| Docker | 24.0+ | Container runtime |
| Docker Compose | 2.21.0 | Service orchestration |
| Ubuntu | 22.04 LTS | Base operating system |
| Java OpenJDK | 17 | Processor runtime |
| Python | 3.11 | Producer runtime |

## High-Level Execution Steps

### 1. Infrastructure Provisioning
```bash
# Deploy AWS infrastructure
chmod +x aws-infrastructure.sh
./aws-infrastructure.sh
```

### 2. Application Deployment
```bash
# On each VM, upload compose files and start services
scp -i kafka-pipeline-key.pem *-compose.yml ubuntu@<vm-ip>:/opt/kafka-pipeline/
ssh -i kafka-pipeline-key.pem ubuntu@<vm-ip>

# Start services per VM
cd /opt/kafka-pipeline

# On kafka-vm
docker-compose -f kafka-compose.yml up -d

# On mongodb-vm  
docker-compose -f mongodb-compose.yml up -d

# On processor-vm
docker-compose -f processor-compose.yml up -d

# On producer-vm
docker-compose -f producer-compose.yml up -d
```

### 3. Verification
- Access Kafka UI: `http://<kafka-vm-public-ip>:8080`
- Access Mongo Express: `http://<mongodb-vm-public-ip>:8081`
- Monitor logs: `docker logs <container-name>`

## Deviations from Reference Stack

### Architecture Changes
1. **ZooKeeper Inclusion**: Added ZooKeeper for stability (original planned KRaft mode had compatibility issues)
2. **Image Updates**: Updated to latest stable versions for better security
3. **VM Sizing**: Adjusted to t2.medium/small for cost optimization while meeting requirements

### Security Enhancements
1. **Firewall Configuration**: UFW enabled with restricted port access
2. **SSH Hardening**: Password authentication disabled, key-only access
3. **Fail2Ban**: Intrusion detection and prevention system
4. **Network Isolation**: Service ports restricted to VPC CIDR

### Container Improvements
1. **Multi-stage Builds**: Reduced image sizes for custom applications
2. **Non-root Users**: Enhanced container security
3. **Health Checks**: Added for service monitoring
4. **Volume Persistence**: Data persistence across container restarts

## Network Configuration

### VPC Layout
- **VPC CIDR**: 10.0.0.0/16
- **Public Subnet**: 10.0.1.0/24
- **Region**: us-east-2 (configurable)

### Security Groups
- **SSH (22)**: Internet access for administration
- **Kafka (9092)**: VPC-internal only
- **MongoDB (27017)**: VPC-internal only  
- **Management UIs (8080/8081)**: Internet access for monitoring

### Data Flow
```
Producer (10.0.1.13) → Kafka (10.0.1.10:9092) → Processor (10.0.1.12) → MongoDB (10.0.1.11:27017)
```

## Security Controls Implemented

1. **Network Security**
   - VPC isolation with security groups
   - UFW firewall on each VM
   - Port restrictions by service role

2. **Access Control**
   - SSH key-only authentication
   - Fail2ban for intrusion prevention
   - Non-root container execution

3. **System Hardening**
   - Disabled unnecessary services
   - Kernel parameter tuning
   - Log rotation and monitoring

## Testing and Validation

### End-to-End Test
1. Producer generates sample sensor data
2. Messages published to Kafka topic
3. Processor consumes and transforms data
4. Processed data stored in MongoDB
5. Verification via management UIs

### Monitoring Points
- Kafka UI: Topic throughput and consumer lag
- Mongo Express: Database collections and documents
- System logs: Service health and errors
- Docker stats: Resource utilization

## Project Structure
```
CA0/
├── README.md                    # This file
├── NETWORK_DIAGRAM.md          # Network architecture diagram
├── CONFIGURATION_TABLE.md      # Detailed component configuration
├── aws-infrastructure.sh       # AWS provisioning script
├── user-data.sh               # VM initialization script
├── kafka-compose.yml          # Kafka services
├── mongodb-compose.yml        # MongoDB services  
├── processor-compose.yml      # Java processor service
├── producer-compose.yml       # Python producer service
├── init-mongo.js             # MongoDB initialization
├── processor/                # Java application source
└── producer/                 # Python application source
```

## Deployment Checklist

- [x] AWS infrastructure scripts prepared
- [x] Container images built and tested locally
- [x] Security hardening configurations implemented
- [x] Network diagram and documentation completed
- [x] End-to-end data flow verified
- [x] Management interfaces configured
- [x] Monitoring and logging setup
- [x] Backup and persistence configured