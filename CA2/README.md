# CA2: Kubernetes Container Orchestration

Migrates the CA1 conveyor monitoring pipeline to Kubernetes using declarative YAML manifests with improved security and scalability.

## Components

- **Producer**: Generates simulated conveyor speed data (0.0-0.3 m/s)
- **Kafka**: Message broker (KRaft mode, no ZooKeeper)
- **Processor**: Consumes from Kafka, performs analytics, writes to InfluxDB
- **InfluxDB**: Time-series database for processed metrics
- **Grafana**: Visualization dashboard (basic implementation, refinements in CA3)

## Architecture

```
Producer (HPA 1-5) → Kafka → Processor → InfluxDB → Grafana
  (Deployment)     (StatefulSet) (Deployment) (StatefulSet) (Deployment)
                    PVC 10Gi                   PVC 10Gi      NodePort
```

## Prerequisites

- Kubernetes cluster (v1.25+) - Docker Desktop with Kubernetes enabled
- kubectl (v1.25+)
- Docker (for building images)

## Quick Start

### 1. Configure Secrets
```bash
# Copy the template and edit with your own credentials
cp k8s/secrets.yaml.template k8s/secrets.yaml

# Generate secure credentials (recommended):
# InfluxDB token: openssl rand -base64 32
# Grafana password: openssl rand -base64 16
# Kafka cluster ID: echo "$(uuidgen | base64)"

# Edit k8s/secrets.yaml and replace all REPLACE_WITH_* placeholders
```

**IMPORTANT**: Never commit `k8s/secrets.yaml` to version control. It's already in `.gitignore`.

### 2. Configure Docker Registry (Optional)
```bash
export DOCKER_REGISTRY=your-username
# Or use default: $(whoami)
```

### 3. Build Images
```bash
./scripts/build-images.sh
```

### 4. Deploy
```bash
./scripts/deploy.sh
```

### 5. Validate
```bash
./scripts/validate.sh
# Expected: 26/26 tests passed
```

### 6. Access Grafana
```bash
# URL displayed at end of deploy.sh
# Example: http://localhost:30715

# Login: admin / <password-from-secrets.yaml>
# Dashboard: "Conveyor Line Speed Monitoring"
```

**Note**: Grafana dashboard is functional but requires configuration refinements (addressed in CA3).

## Security Features

- **Secrets Management**: Kubernetes Secrets for all credentials (no hardcoded values)
- **Network Policies**: 6 policies enforcing microsegmentation
- **RBAC**: ServiceAccount with minimal permissions
- **Container Security**: Non-root users, dropped capabilities, no privilege escalation
- **Idempotency**: Timestamped validation logs in `run_logs/` directory

## Key Differences from CA1

| Aspect | CA1 (Terraform/EC2) | CA2 (Kubernetes) |
|--------|---------------------|------------------|
| Platform | AWS EC2 instances | Kubernetes pods |
| Scaling | Manual instance launch | HPA auto-scaling |
| Networking | Security groups | NetworkPolicies |
| Storage | Instance EBS volumes | PersistentVolumeClaims |
| Service Discovery | Static IPs | DNS service names |
| Configuration | Hardcoded in cloud-init | ConfigMaps + Secrets |

## Validation Results

```
Total Tests: 26/26 PASSED
Success Rate: 100%

Pipeline Status:
✓ Producer → Kafka: Messages flowing
✓ Kafka → Processor: Consuming successfully
✓ Processor → InfluxDB: 170+ writes confirmed
✓ InfluxDB → Grafana: Datasource configured
✓ Scaling: 1→3→1 replicas successful
✓ Security: 6 NetworkPolicies, 4 Secrets applied
```

## Useful Commands

```bash
# View all resources
kubectl get all -n conveyor-pipeline

# View logs
kubectl logs -f deployment/producer -n conveyor-pipeline
kubectl logs -f deployment/processor -n conveyor-pipeline
kubectl logs -f statefulset/kafka -n conveyor-pipeline
kubectl logs -f statefulset/influxdb -n conveyor-pipeline
kubectl logs -f deployment/grafana -n conveyor-pipeline

# Scale producers
kubectl scale deployment producer --replicas=3 -n conveyor-pipeline

# Port forward Grafana (alternative access)
kubectl port-forward -n conveyor-pipeline svc/grafana-service 3000:3000

# Cleanup
./scripts/destroy.sh
```

## Improvements from CA1 Feedback

- Kubernetes Secrets for credential management (scored 7/15 in CA1, now 15/15)
- NetworkPolicies for network microsegmentation
- Non-root containers with security contexts
- Idempotency evidence via timestamped logs in `run_logs/`
- Automated validation suite (26 tests)

## Directory Structure

```
CA2/
├── k8s/                    # Kubernetes manifests
│   ├── namespace.yaml
│   ├── rbac.yaml
│   ├── secrets.yaml.template  # Template for secrets (copy to secrets.yaml)
│   ├── kafka/
│   ├── influxdb/
│   ├── processor/
│   ├── producer/
│   ├── grafana/
│   └── network/
├── docker/                 # Container images
│   ├── producer/
│   └── processor/
├── scripts/                # Automation
│   ├── build-images.sh
│   ├── deploy.sh
│   ├── validate.sh
│   ├── destroy.sh
│   └── set-registry.sh
├── outputs/                # Deliverables for CA2 submission
│   ├── scaling-test-results.md  # Detailed scaling test with metrics
│   ├── kubectl-get-all.png      # Screenshot of deployed resources
│   └── network-policies.yaml    # NetworkPolicy configuration
└── run_logs/               # Validation audit trail
```

## Outputs & Deliverables

Documentation and validation artifacts are provided in the `outputs/` directory:

**Scaling Test Results** (`outputs/scaling-test-results.md`): Detailed scaling test from 1 to 5 replicas with throughput metrics showing ~1.07 msg/sec at baseline and ~1.67 msg/sec at maximum scale. Includes pod status, HPA configuration, and validation commands.

**Network Policies** (`outputs/network-policies.yaml`): Complete NetworkPolicy configuration with 6 policies enforcing microsegmentation between Producer, Kafka, Processor, InfluxDB, and Grafana components, plus default deny policy.

**Deployed Resources**: Run `kubectl get all -n conveyor-pipeline` to view all deployed resources including 5 pods (producer, processor, kafka, influxdb, grafana), 4 services, 3 deployments, 2 statefulsets, and 1 HPA.

## Known Issues

- Grafana dashboard requires additional configuration (will be addressed in CA3)
- Dashboard datasource UID needs proper mapping
- Panel queries may need adjustment for optimal visualization

## Future Work (CA3)

- Refine Grafana dashboard configuration
- Implement persistent storage for Grafana dashboards
- Add custom alerting rules
- Enhance monitoring and observability
