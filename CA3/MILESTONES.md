# CA3 Implementation Milestones

## Milestone-Based Approach

Each milestone must be completed and verified before proceeding to the next. This ensures a stable, incremental build with clear validation at each step.

---

## Milestone 1: Foundation Setup

**Objective:** Copy CA2 to CA3 and verify baseline deployment works.

### Tasks
1. Copy entire CA2 directory structure to CA3
2. Keep namespace as `conveyor-pipeline` (no namespace changes needed)
3. Copy secrets.yaml from CA2 to CA3
4. Run deployment scripts

### Verification Criteria
- [ ] All CA3 manifests reference `conveyor-pipeline` namespace
- [ ] `./scripts/deploy.sh` completes successfully
- [ ] `./scripts/validate.sh` shows 26/26 tests passed
- [ ] `kubectl get all -n conveyor-pipeline` shows all pods running
- [ ] Grafana accessible at NodePort URL
- [ ] Producer generating data, processor writing to InfluxDB

### Deliverables
- CA3 directory with copied structure
- Successful deployment and validation logs

### User Approval Required
**You must verify:** Run `kubectl get all -n conveyor-pipeline` and confirm all resources are healthy before proceeding to Milestone 2.

---

## Milestone 2: Prometheus Deployment

**Objective:** Deploy Prometheus for metrics collection.

### Tasks
1. Create `k8s/prometheus/` directory
2. Create Prometheus deployment manifest
3. Create Prometheus service (ClusterIP)
4. Create Prometheus ConfigMap with scrape configs
5. Create RBAC for Prometheus (ServiceAccount, ClusterRole, ClusterRoleBinding)
6. Deploy Prometheus to CA3 namespace
7. Verify Prometheus UI is accessible

### Verification Criteria
- [ ] Prometheus pod running in `conveyor-pipeline` namespace
- [ ] Prometheus service created and accessible
- [ ] Port-forward to Prometheus UI: `kubectl port-forward -n conveyor-pipeline svc/prometheus-service 9090:9090`
- [ ] Access http://localhost:9090 shows Prometheus UI
- [ ] Prometheus "Status > Targets" shows at least Prometheus itself as a target
- [ ] Prometheus can query basic metrics (e.g., `up`)

### Deliverables
- `k8s/prometheus/prometheus-deployment.yaml`
- `k8s/prometheus/prometheus-service.yaml`
- `k8s/prometheus/prometheus-configmap.yaml`
- `k8s/prometheus/prometheus-rbac.yaml`
- Screenshot of Prometheus UI showing targets

### User Approval Required
**You must verify:** Access Prometheus UI and confirm it's scraping metrics before proceeding to Milestone 3.

---

## Milestone 3: Application Metrics Instrumentation

**Objective:** Add metrics endpoints to producer and processor applications.

### Tasks
1. Update producer Python code to expose metrics endpoint using `prometheus_client`
2. Update processor Python code to expose metrics endpoint
3. Add metrics for:
   - Producer: messages sent per second, total messages sent
   - Processor: messages consumed per second, InfluxDB writes per second
4. Rebuild Docker images with metrics instrumentation
5. Update Prometheus ConfigMap to scrape producer and processor pods
6. Redeploy updated applications

### Verification Criteria
- [ ] Producer pod exposes metrics at `/metrics` endpoint (port 8000)
- [ ] Processor pod exposes metrics at `/metrics` endpoint (port 8000)
- [ ] `kubectl exec -n conveyor-pipeline <producer-pod> -- curl localhost:8000/metrics` returns Prometheus metrics
- [ ] Prometheus UI shows producer and processor as targets
- [ ] Prometheus can query custom metrics: `producer_messages_sent_total`, `processor_messages_consumed_total`

### Deliverables
- Updated `docker/producer/conveyor_producer.py` with metrics
- Updated `docker/processor/conveyor_processor.py` with metrics
- Updated Docker images pushed to registry
- Updated Prometheus ConfigMap with scrape configs
- Screenshot of Prometheus targets showing producer/processor

### User Approval Required
**You must verify:** Query custom metrics in Prometheus UI and see non-zero values before proceeding to Milestone 4.

---

## Milestone 4: Enhanced Grafana Dashboards

**Objective:** Create production-grade Grafana dashboards with required metrics.

### Tasks
1. Update Grafana datasource ConfigMap to include Prometheus
2. Create new Grafana dashboard JSON with three required panels:
   - Panel 1: Producer rate (events emitted/sec)
   - Panel 2: Processor rate (messages consumed/sec)
   - Panel 3: Database inserts/sec (InfluxDB writes)
3. Update Grafana dashboard ConfigMap with new dashboard
4. Redeploy Grafana with updated configurations
5. Verify dashboards display live metrics

### Verification Criteria
- [ ] Grafana shows Prometheus datasource as connected
- [ ] New dashboard "CA3 Pipeline Metrics" appears in Grafana
- [ ] Panel 1 shows producer message rate > 0
- [ ] Panel 2 shows processor consumption rate > 0
- [ ] Panel 3 shows InfluxDB write rate > 0
- [ ] All panels update in real-time (5s refresh)

### Deliverables
- Updated `k8s/grafana/grafana-datasource-configmap.yaml` (add Prometheus)
- Updated `k8s/grafana/grafana-dashboard-configmap.yaml` (new dashboard)
- Screenshot of Grafana dashboard with all three panels showing data

### User Approval Required
**You must verify:** Access Grafana UI and confirm all three metric panels are displaying live data before proceeding to Milestone 5.

---

## Milestone 5: Centralized Logging (Loki + Promtail)

**Objective:** Deploy centralized log aggregation with Loki and Promtail.

### Tasks
1. Create `k8s/logging/` directory
2. Create Loki deployment manifest (log aggregation backend)
3. Create Loki service (ClusterIP)
4. Create Loki ConfigMap
5. Create Promtail DaemonSet (log collector on each node)
6. Create Promtail ConfigMap with scrape configs for pod logs
7. Deploy Loki and Promtail to CA3 namespace
8. Update Grafana datasource ConfigMap to include Loki
9. Verify logs are being collected and queryable

### Verification Criteria
- [ ] Loki pod running in `conveyor-pipeline` namespace
- [ ] Promtail DaemonSet running (1 pod per node)
- [ ] Grafana shows Loki datasource as connected
- [ ] In Grafana Explore, can query logs: `{namespace="conveyor-pipeline"}`
- [ ] Logs visible from producer, processor, kafka, influxdb pods
- [ ] Can filter logs by pod label: `{namespace="conveyor-pipeline", app="producer"}`
- [ ] Can search for specific log content (e.g., "Speed:", "Writing to InfluxDB")

### Deliverables
- `k8s/logging/loki-deployment.yaml`
- `k8s/logging/loki-service.yaml`
- `k8s/logging/loki-configmap.yaml`
- `k8s/logging/promtail-daemonset.yaml`
- `k8s/logging/promtail-configmap.yaml`
- Updated Grafana datasource ConfigMap
- Screenshot of Grafana Explore showing logs from multiple pods
- Screenshot of log search filtered by "error" or specific keyword

### User Approval Required
**You must verify:** Query logs in Grafana Explore and successfully filter by pod/keyword before proceeding to Milestone 6.

---

## Milestone 6: Load Testing & HPA Validation

**Objective:** Create load testing and validate autoscaling behavior.

### Tasks
1. Create `scripts/load-test.sh` to generate high message throughput
2. Document baseline metrics (1 producer replica)
3. Run load test to trigger HPA scaling
4. Capture HPA events: `kubectl get hpa -n conveyor-pipeline --watch`
5. Observe scaling: 1 → N replicas
6. Stop load test and observe scale-down
7. Document metrics at each scaling level

### Verification Criteria
- [ ] Load test script successfully generates high traffic
- [ ] HPA triggers scale-up event (visible in `kubectl describe hpa`)
- [ ] Producer replicas increase from 1 to 2+ during load test
- [ ] Grafana shows increased message throughput during load
- [ ] After load stops, HPA scales back down to 1 replica
- [ ] Complete scaling cycle documented with timestamps

### Deliverables
- `scripts/load-test.sh` script
- `outputs/hpa-scaling-events.txt` (kubectl get hpa output over time)
- `outputs/hpa-scaling.png` (screenshot of scaling events)
- Updated `outputs/scaling-test-results.md` with load test data

### User Approval Required
**You must verify:** Review load test results and confirm HPA scaled up and down correctly before proceeding to Milestone 7.

---

## Milestone 7: TLS for InfluxDB

**Objective:** Enable TLS encryption for InfluxDB connections.

### Tasks
1. Create `k8s/tls/` directory
2. Create script to generate self-signed certificates for InfluxDB
3. Create Kubernetes Secret with TLS certificate and key
4. Update InfluxDB StatefulSet to mount TLS certificates
5. Update InfluxDB ConfigMap to enable TLS
6. Update processor deployment to connect via HTTPS
7. Update Grafana datasource to use HTTPS
8. Verify TLS connections work

### Verification Criteria
- [ ] TLS certificates generated and stored as Kubernetes Secret
- [ ] InfluxDB pod mounts TLS certificate and key
- [ ] InfluxDB logs show TLS enabled on startup
- [ ] Processor successfully connects to InfluxDB via HTTPS
- [ ] Grafana datasource connects to InfluxDB via HTTPS
- [ ] `kubectl logs` shows no TLS handshake errors
- [ ] Data still flows: Producer → Kafka → Processor → InfluxDB (HTTPS)

### Deliverables
- `k8s/tls/generate-influxdb-certs.sh` script
- `k8s/tls/influxdb-tls-secret.yaml.template`
- Updated `k8s/influxdb/influxdb-statefulset.yaml` (TLS config)
- Updated `k8s/influxdb/influxdb-configmap.yaml` (TLS enabled)
- Updated `k8s/processor/processor-deployment.yaml` (HTTPS connection)
- Updated `k8s/grafana/grafana-datasource-configmap.yaml` (HTTPS)
- `outputs/tls-config-summary.md` documenting TLS setup

### User Approval Required
**You must verify:** Check processor logs showing successful HTTPS connections to InfluxDB before proceeding to Milestone 8.

---

## Milestone 8: TLS for Kafka (Optional - Complex)

**Objective:** Enable TLS encryption for Kafka broker and client connections.

**Note:** This is the most complex milestone. If time is limited, this can be skipped or simplified.

### Tasks
1. Generate TLS certificates for Kafka broker
2. Create Kubernetes Secret with Kafka TLS certificates
3. Update Kafka StatefulSet to enable TLS listeners
4. Update Kafka ConfigMap with TLS settings
5. Update producer deployment to connect via TLS
6. Update processor deployment to consume via TLS
7. Verify TLS connections for both producers and consumers

### Verification Criteria
- [ ] Kafka broker starts with TLS enabled
- [ ] Kafka listens on TLS port (9093)
- [ ] Producer successfully sends messages via TLS
- [ ] Processor successfully consumes messages via TLS
- [ ] No plaintext connections on port 9092
- [ ] `kubectl exec` into Kafka pod and verify TLS config

### Deliverables
- `k8s/tls/generate-kafka-certs.sh` script
- `k8s/tls/kafka-tls-secret.yaml.template`
- Updated `k8s/kafka/kafka-statefulset.yaml` (TLS config)
- Updated `k8s/producer/producer-deployment.yaml` (TLS connection)
- Updated `k8s/processor/processor-deployment.yaml` (TLS connection)
- Updated `outputs/tls-config-summary.md`

### User Approval Required
**You must verify:** Check producer and processor logs showing successful TLS connections to Kafka. If this milestone is too complex, you may skip to Milestone 9.

---

## Milestone 9: Resilience Testing

**Objective:** Perform failure injection and validate self-healing.

### Tasks
1. Create `scripts/resilience-test.sh` for automated failure injection
2. Set up screen recording (OBS, QuickTime, or similar)
3. Record resilience drill video showing:
   - Delete producer pod → observe automatic restart
   - Delete processor pod → observe automatic restart
   - Delete Kafka pod → observe StatefulSet recovery
   - Show logs during recovery
   - Show operator troubleshooting steps
4. Document operator response procedures
5. Verify pipeline continues functioning after each failure

### Verification Criteria
- [ ] Video recording (≤3 min) shows all failure scenarios
- [ ] Each deleted pod is automatically recreated by Kubernetes
- [ ] Pods return to Running state within 30 seconds
- [ ] Pipeline continues processing data after recovery
- [ ] Video shows clear operator actions (checking logs, status)
- [ ] Written documentation explains troubleshooting steps

### Deliverables
- `scripts/resilience-test.sh` script
- `outputs/resilience-drill.mp4` video (≤3 min)
- `outputs/operator-procedures.md` documenting response steps
- Screenshots of pod recovery in `kubectl get pods` output

### User Approval Required
**You must verify:** Watch the video and confirm it clearly shows failure, recovery, and troubleshooting before proceeding to Milestone 10.

---

## Milestone 10: Documentation & Outputs

**Objective:** Finalize all documentation and organize deliverables.

### Tasks
1. Update CA3 README.md with:
   - Observability setup instructions (Prometheus, Grafana, Loki)
   - Load testing instructions
   - TLS configuration details
   - Resilience testing procedures
   - All new components and their purpose
2. Organize outputs/ directory with all required deliverables
3. Verify all screenshots are present and clear
4. Run final validation: `./scripts/validate.sh`
5. Run final deployment test: `./scripts/destroy.sh` && `./scripts/deploy.sh`

### Verification Criteria
- [ ] README.md updated with all CA3 additions
- [ ] All required outputs present in `outputs/` directory:
  - [ ] grafana-dashboard.png (3 metrics panels)
  - [ ] log-search.png (filtered logs)
  - [ ] hpa-scaling.png (scaling events)
  - [ ] network-policies.yaml (from CA2)
  - [ ] tls-config-summary.md
  - [ ] resilience-drill.mp4 (video)
  - [ ] operator-procedures.md
- [ ] Deploy script works on clean cluster
- [ ] Validate script passes all tests
- [ ] README instructions are clear and complete

### Deliverables
- Complete CA3 README.md
- All outputs organized in `outputs/` directory
- Clean deployment from scratch succeeds

### User Approval Required
**You must verify:** Review final README and all outputs to ensure submission readiness before committing to GitHub.

---

## Milestone 11: GitHub Submission

**Objective:** Commit and push CA3 to GitHub repository.

### Tasks
1. Review all files to ensure no secrets are committed
2. Verify `.gitignore` excludes `secrets.yaml`
3. Stage CA3 directory: `git add CA3/`
4. Create concise commit message
5. Push to GitHub
6. Verify repository looks correct on GitHub web interface

### Verification Criteria
- [ ] No secrets.yaml files committed
- [ ] All manifests, scripts, and outputs present
- [ ] Commit message is clear and concise
- [ ] GitHub repository shows CA3 directory correctly
- [ ] README.md renders properly on GitHub

### Deliverables
- CA3 committed to GitHub
- Clean repository with no sensitive data

### Final Approval
**You must verify:** Review GitHub repository and confirm CA3 is ready for submission.

---

## Summary of Verification Points

After each milestone, you must:
1. Run the verification commands listed
2. Check all verification criteria are met
3. Review deliverables
4. Give explicit approval to proceed

If any verification fails, we stop and fix the issue before moving forward. This ensures each layer is solid before adding complexity.

## Estimated Timeline

| Milestone | Estimated Time | Complexity |
|-----------|----------------|------------|
| M1: Foundation | 30 min | Low |
| M2: Prometheus | 1 hour | Medium |
| M3: Metrics | 1-2 hours | Medium |
| M4: Grafana | 1 hour | Low |
| M5: Logging | 1-2 hours | Medium |
| M6: Load Testing | 1 hour | Low |
| M7: InfluxDB TLS | 1 hour | Low |
| M8: Kafka TLS | 2-3 hours | High (Optional) |
| M9: Resilience | 1 hour | Low |
| M10: Documentation | 1 hour | Low |
| M11: GitHub | 15 min | Low |

**Total: ~11-14 hours** (excluding Kafka TLS)

## Next Steps

1. You review this milestone plan
2. You give approval to start Milestone 1
3. I execute Milestone 1 tasks
4. You verify Milestone 1 criteria
5. You approve proceeding to Milestone 2
6. Repeat until all milestones complete
