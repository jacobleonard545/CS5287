# Network Diagram - Kafka Data Pipeline

## Architecture Overview
```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                   VPC: 10.0.0.0/16                                 │
│                              Security Group: kafka-pipeline-sg                     │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────┐
│                               Public Subnet: 10.0.1.0/24                           │
│                                                                                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   VM1: Kafka    │  │  VM2: MongoDB   │  │ VM3: Processor  │  │  VM4: Producer  │  │
│  │  10.0.1.10:22   │  │  10.0.1.11:22   │  │  10.0.1.12:22   │  │  10.0.1.13:22   │  │
│  │  10.0.1.10:9092 │  │ 10.0.1.11:27017 │  │                 │  │                 │  │
│  │  10.0.1.10:8080 │  │  10.0.1.11:8081 │  │                 │  │                 │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│           │                    │                    │                    │           │
└───────────┼────────────────────┼────────────────────┼────────────────────┼───────────┘
            │                    │                    │                    │
┌───────────▼────────────────────▼────────────────────▼────────────────────▼───────────┐
│                              Internet Gateway                                        │
└─────────────────────────────────────────────────────────────────────────────────────┘
            │                    │                    │                    │
            ▼                    ▼                    ▼                    ▼
    ┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
    │   SSH:22     │     │   SSH:22     │     │   SSH:22     │     │   SSH:22     │
    │ Kafka:9092   │     │  Mongo:27017 │     │              │     │              │
    │ UI:8080      │     │  UI:8081     │     │              │     │              │
    └──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
```

## Network Configuration

### VPC Details
- **CIDR Block**: 10.0.0.0/16
- **Region**: us-east-1 (configurable)
- **Availability Zone**: us-east-1a

### Subnet Configuration
- **Public Subnet**: 10.0.1.0/24
- **Internet Gateway**: Attached for public access
- **Route Table**: Default route (0.0.0.0/0) → Internet Gateway

### Security Group Rules
**Inbound Rules:**
- SSH (22): 0.0.0.0/0 (restricted to key-only authentication)
- Kafka (9092): 10.0.0.0/16 (internal VPC only)
- MongoDB (27017): 10.0.0.0/16 (internal VPC only)
- Kafka UI (8080): 0.0.0.0/0 (management interface)
- Mongo Express (8081): 0.0.0.0/0 (management interface)

**Outbound Rules:**
- All traffic (0.0.0.0/0) on all ports (for package installation and updates)

### Trust Boundaries
1. **Internet ↔ Public Subnet**: Controlled via Security Groups
2. **VM-to-VM**: Internal VPC communication for service ports
3. **SSH Access**: Key-based authentication only
4. **Service Communication**: Restricted to VPC CIDR block

### Data Flow
1. **Producer** → **Kafka Broker** (port 9092)
2. **Kafka Broker** → **Processor** (consumer polling)
3. **Processor** → **MongoDB** (port 27017)
4. **Management UIs** ← **Internet** (ports 8080, 8081)