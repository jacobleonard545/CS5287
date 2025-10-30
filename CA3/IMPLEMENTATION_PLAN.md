# CA3 Implementation Plan

## Overview

CA3 builds upon CA2 by adding production-grade observability, enhanced security hardening, and resilience testing. The strategy is to replicate CA2 as a baseline and incrementally add cloud-native operational capabilities.

## Foundation from CA2

### Already Complete

**Security Hardening (Partial)**
- Kubernetes Secrets for credential management
- NetworkPolicies (6 policies enforcing microsegmentation)
- RBAC with ServiceAccount and minimal permissions
- Non-root containers with security contexts

**Autoscaling (Partial)**
- HPA configured for producer (1-5 replicas, CPU target 70%)
- Successful scaling validation (1→3→5→1 replicas)

**Infrastructure**
- Complete pipeline: Producer → Kafka → Processor → InfluxDB → Grafana
- Automated deployment, validation, and cleanup scripts
- StatefulSets for Kafka and InfluxDB with persistent storage

## Net-New Implementations Required

### 1. Observability (Major Addition)

**Metrics Collection**
- Deploy Prometheus for metrics scraping
- Configure ServiceMonitors for all components
- Expose metrics endpoints on applications

**Enhanced Grafana Dashboards**
- Producer rate: events emitted/sec
- Kafka consumer lag: `kafka_consumergroup_lag{group="processor"}`
- Database inserts/sec: count of writes per second
- Minimum 3 panels showing metrics over time

**Centralized Logging**
- Deploy Loki + Promtail (or EFK stack)
- Configure log collection from all pipeline pods
- Structured logs with timestamps, pod labels, service tags
- Log aggregation with searchable interface

**Deliverables:**
- Screenshot of log search filtered across components
- Screenshot of Grafana dashboard with three key metrics

### 2. Enhanced Autoscaling

**HPA Enhancement**
- Document existing producer HPA configuration
- Optionally add processor HPA
- Configure custom metrics (e.g., Kafka consumer lag)

**Load Testing**
- Create load generation script
- Push high event throughput to trigger scaling
- Observe HPA scaling events in real-time
- Verify scale-down after load subsides

**Deliverables:**
- HPA manifest snippets
- Screenshots of `kubectl get hpa` over time
- Load test results showing scaling behavior

### 3. Security Hardening (TLS Addition)

**TLS Encryption**
- Enable TLS for Kafka (broker-to-broker and client)
- Enable TLS for InfluxDB connections
- Use self-signed certificates or cert-manager
- Store certificates as Kubernetes Secrets

**Network Isolation**
- Already have NetworkPolicies from CA2
- Document existing security controls

**Deliverables:**
- NetworkPolicy YAML (existing from CA2)
- Secret templates (sanitized)
- TLS configuration summary

### 4. Resilience Drill (New Validation)

**Failure Injection**
- Delete pods in each tier (`kubectl delete pod`)
- Simulate network failures if time permits
- Test self-healing behavior

**Self-Healing Validation**
- Demonstrate Kubernetes automatic pod restart
- Monitor pod status during recovery
- Verify pipeline continues functioning

**Operator Response**
- Document troubleshooting steps
- Log analysis procedures
- Manual intervention scenarios

**Deliverables:**
- Video (≤3 min) showing pod failure, recovery, troubleshooting
- Written documentation of operator procedures

## Implementation Complexity Assessment

| Component | Effort | Priority | Notes |
|-----------|--------|----------|-------|
| Prometheus | Medium | High | Standard manifests, ServiceMonitor configs |
| Enhanced Grafana | Low | High | Already have Grafana, add dashboards |
| Loki + Promtail | Medium | High | DaemonSet + config, Grafana integration |
| TLS for InfluxDB | Low | Medium | Straightforward TLS configuration |
| TLS for Kafka | High | Medium | Complex, cert generation required |
| Load Testing | Low | High | Script to generate traffic |
| Resilience Tests | Low | High | Pod deletion scripts |
| Video Recording | Low | High | Screen capture of failure scenarios |

## Proposed Directory Structure

```
CA3/
├── k8s/                           # Kubernetes manifests (from CA2)
│   ├── namespace.yaml
│   ├── rbac.yaml
│   ├── secrets.yaml.template
│   ├── kafka/
│   ├── influxdb/
│   ├── processor/
│   ├── producer/
│   ├── grafana/                   # Enhanced with better dashboards
│   ├── network/
│   ├── prometheus/                # NEW: Prometheus setup
│   │   ├── prometheus-deployment.yaml
│   │   ├── prometheus-service.yaml
│   │   ├── prometheus-configmap.yaml
│   │   └── servicemonitor.yaml
│   ├── logging/                   # NEW: Centralized logging
│   │   ├── loki-deployment.yaml
│   │   ├── loki-service.yaml
│   │   ├── promtail-daemonset.yaml
│   │   └── promtail-configmap.yaml
│   └── tls/                       # NEW: TLS certificates
│       ├── cert-generator.sh
│       ├── kafka-tls-secret.yaml
│       └── influxdb-tls-secret.yaml
├── docker/                        # Container images (from CA2)
│   ├── producer/                  # May need metrics endpoint
│   └── processor/                 # May need metrics endpoint
├── scripts/                       # Automation (from CA2, enhanced)
│   ├── build-images.sh
│   ├── deploy.sh
│   ├── validate.sh
│   ├── destroy.sh
│   ├── load-test.sh               # NEW: Load generation
│   └── resilience-test.sh         # NEW: Failure injection
├── outputs/                       # Deliverables for CA3
│   ├── grafana-dashboard.png
│   ├── log-search.png
│   ├── hpa-scaling.png
│   ├── network-policies.yaml
│   ├── tls-config-summary.md
│   └── resilience-drill.mp4       # Video recording
└── run_logs/                      # Validation audit trail
```

## Implementation Sequence

### Phase 1: Foundation (Copy CA2)
1. Copy entire CA2 directory structure to CA3
2. Verify deployment works in CA3 context
3. Update README with CA3 goals

### Phase 2: Observability (High Priority)
1. Deploy Prometheus with ServiceMonitors
2. Enhance Grafana with required dashboards
3. Deploy Loki + Promtail for centralized logging
4. Capture screenshots of logs and metrics

### Phase 3: Load Testing & Autoscaling
1. Create load generation script
2. Run load tests and capture HPA scaling
3. Document scaling behavior with screenshots

### Phase 4: TLS Hardening
1. Generate TLS certificates
2. Configure InfluxDB TLS (easier)
3. Configure Kafka TLS (more complex)
4. Update application configs for TLS

### Phase 5: Resilience Testing
1. Create failure injection scripts
2. Record resilience drill video
3. Document operator procedures
4. Validate self-healing behavior

### Phase 6: Documentation & Submission
1. Update README with all new components
2. Organize outputs directory
3. Validate all deliverables
4. Commit to GitHub

## Key Differences: CA2 vs CA3

| Aspect | CA2 | CA3 |
|--------|-----|-----|
| Focus | Container orchestration | Production operations |
| Observability | Basic Grafana | Prometheus + enhanced Grafana + Loki |
| Logging | Pod logs only | Centralized log aggregation |
| Metrics | None | Producer rate, consumer lag, DB writes |
| Security | Secrets + NetworkPolicies | + TLS encryption |
| Scaling | HPA configured | HPA + load testing + validation |
| Resilience | Implicit | Explicit failure testing + video |

## Grading Breakdown

- **Observability & Logging** (25%) - Prometheus, Grafana dashboards, Loki
- **Autoscaling Configuration** (20%) - HPA + load tests
- **Security Hardening** (20%) - TLS + existing NetworkPolicies
- **Resilience Drill & Recovery** (25%) - Failure injection + video
- **Documentation & Usability** (10%) - README + deliverables

## Notes

- **Start Simple**: Begin with Prometheus and basic Grafana dashboards
- **Iterate**: Add complexity incrementally (logging, then TLS)
- **Test Early**: Validate each component before moving to next
- **Kafka TLS**: Most complex component, allocate extra time
- **Video**: Keep under 3 minutes, focus on key failure scenarios
- **Documentation**: Update README as you go, not at the end

## Next Steps

1. Wait for user approval of this plan
2. Copy CA2 directory structure to CA3
3. Begin Phase 1: Foundation setup
4. Proceed through phases sequentially
