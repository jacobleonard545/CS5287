# Configuration Summary Table

## Component Configuration Overview

| Component | Image/Version | Host VM | Port(s) | Purpose | Dependencies |
|-----------|---------------|---------|---------|---------|--------------|
| **ZooKeeper** | confluentinc/cp-zookeeper:7.4.0 | kafka-vm (10.0.1.10) | 2181 | Kafka coordination service | None |
| **Kafka Broker** | confluentinc/cp-kafka:7.4.0 | kafka-vm (10.0.1.10) | 9092 | Message streaming platform | ZooKeeper |
| **Kafka UI** | provectuslabs/kafka-ui:latest | kafka-vm (10.0.1.10) | 8080 | Kafka management interface | Kafka, ZooKeeper |
| **MongoDB** | mongo:6.0 | mongodb-vm (10.0.1.11) | 27017 | Document database | None |
| **Mongo Express** | mongo-express:latest | mongodb-vm (10.0.1.11) | 8081 | MongoDB web interface | MongoDB |
| **Data Processor** | kafka-processor:latest | processor-vm (10.0.1.12) | - | Java consumer service | Kafka, MongoDB |
| **Data Producer** | kafka-producer:latest | producer-vm (10.0.1.13) | - | Python producer service | Kafka |

## VM Specifications

| VM Name | Purpose | Size | vCPU | RAM | OS | Public IP | Private IP |
|---------|---------|------|------|-----|----|-----------| -----------|
| kafka-vm | Kafka + ZooKeeper + UI | t2.medium | 2 | 4 GB | Ubuntu 22.04 LTS | Dynamic | 10.0.1.10 |
| mongodb-vm | MongoDB + UI | t2.medium | 2 | 4 GB | Ubuntu 22.04 LTS | Dynamic | 10.0.1.11 |
| processor-vm | Data Processor | t2.small | 1 | 2 GB | Ubuntu 22.04 LTS | Dynamic | 10.0.1.12 |
| producer-vm | Data Producer | t2.small | 1 | 2 GB | Ubuntu 22.04 LTS | Dynamic | 10.0.1.13 |

## Software Versions

| Software | Version | Notes |
|----------|---------|-------|
| Docker | 24.0.x | Container runtime |
| Docker Compose | 2.x | Service orchestration |
| Kafka | 7.4.0 | Confluent Platform |
| ZooKeeper | 7.4.0 | Bundled with Kafka |
| MongoDB | 6.0 | Document database |
| Java OpenJDK | 17 | Processor runtime |
| Python | 3.11 | Producer runtime |
| Ubuntu | 22.04 LTS | Base operating system |

## Environment Variables

### Kafka Configuration
- `KAFKA_BROKER_ID`: 1
- `KAFKA_ZOOKEEPER_CONNECT`: zookeeper:2181
- `KAFKA_ADVERTISED_LISTENERS`: PLAINTEXT://kafka:29092,PLAINTEXT_HOST://localhost:9092
- `KAFKA_AUTO_CREATE_TOPICS_ENABLE`: true

### MongoDB Configuration  
- `MONGO_INITDB_ROOT_USERNAME`: admin
- `MONGO_INITDB_ROOT_PASSWORD`: pipeline2023
- `MONGO_INITDB_DATABASE`: sensordata

### Security Settings
- SSH: Key-based authentication only
- Firewall: UFW enabled with specific port rules
- Container users: Non-root execution where possible
- Network: VPC-isolated communication for service ports

## Service Dependencies

```
Producer → Kafka Broker → Processor → MongoDB
    ↓         ↓              ↓         ↓
  [Logs]   [Kafka UI]   [Processing]  [Mongo Express]
```

## Backup & Persistence
- **Kafka**: Data volume mounted at `/var/lib/kafka/data`
- **ZooKeeper**: Data/logs volumes for cluster state
- **MongoDB**: Data volume mounted at `/data/db`
- **Logs**: Centralized logging to `/opt/kafka-pipeline/logs`