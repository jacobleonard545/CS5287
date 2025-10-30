# Operator Response Procedures - CA3 IoT Pipeline

## Overview
This document provides operational procedures for monitoring, troubleshooting, and responding to failures in the CA3 Kubernetes-based IoT data pipeline.

---

## 1. System Health Checks

### Daily Health Check Commands

```bash
# Check all pods status
kubectl get pods -n conveyor-pipeline

# Check resource usage
kubectl top pods -n conveyor-pipeline
kubectl top nodes

# Check HPA status
kubectl get hpa -n conveyor-pipeline

# Check persistent volumes
kubectl get pvc -n conveyor-pipeline
```

### Expected Healthy State
- All pods in `Running` status with `READY 1/1`
- No pod restarts (or minimal restarts)
- CPU/Memory usage within limits
- HPA showing valid metrics (not `<unknown>`)

---

## 2. Failure Detection

### Monitoring Points

1. **Pod Status Monitoring**
   - Command: `kubectl get pods -n conveyor-pipeline --watch`
   - Look for: `CrashLoopBackOff`, `Error`, `Pending`, `ImagePullBackOff`

2. **Application Logs**
   ```bash
   # Producer logs
   kubectl logs -n conveyor-pipeline -l app=producer --tail=50

   # Processor logs
   kubectl logs -n conveyor-pipeline -l app=processor --tail=50

   # Kafka logs
   kubectl logs -n conveyor-pipeline kafka-0 --tail=50

   # InfluxDB logs
   kubectl logs -n conveyor-pipeline influxdb-0 --tail=50
   ```

3. **Grafana Dashboards**
   - Access Grafana UI: `kubectl get svc -n conveyor-pipeline grafana-service`
   - Check "CA3 Pipeline Metrics" dashboard
   - Monitor: Producer rate, Processor rate, InfluxDB writes

4. **Loki Log Search**
   - Use Grafana Explore with Loki datasource
   - Search query: `{namespace="conveyor-pipeline"}`
   - Filter for errors: `{namespace="conveyor-pipeline"} |= "error" or "Error" or "ERROR"`

---

## 3. Common Failure Scenarios

### Scenario 1: Producer Pod Failure

**Symptoms:**
- Producer pod status: `CrashLoopBackOff` or `Error`
- Grafana shows producer rate = 0
- No new messages in Kafka topic

**Diagnosis Steps:**
```bash
# 1. Check pod status
kubectl get pods -n conveyor-pipeline -l app=producer

# 2. View recent logs
kubectl logs -n conveyor-pipeline -l app=producer --tail=100

# 3. Describe pod for events
kubectl describe pod -n conveyor-pipeline -l app=producer

# 4. Check Kafka connectivity
kubectl exec -n conveyor-pipeline -l app=producer -- curl -v telnet://kafka-service:9092
```

**Resolution:**
- **Self-Healing:** Kubernetes automatically restarts failed pods
- **Manual Restart:** `kubectl delete pod -n conveyor-pipeline <producer-pod-name>`
- **Check Configuration:** Verify `KAFKA_BROKER` in ConfigMap
- **Escalation:** If pod fails repeatedly (5+ restarts), investigate image, secrets, or resource limits

**Expected Recovery Time:** 10-30 seconds

---

### Scenario 2: Processor Pod Failure

**Symptoms:**
- Processor pod status: `CrashLoopBackOff` or `Error`
- Kafka topic accumulates unprocessed messages
- InfluxDB write rate drops to 0

**Diagnosis Steps:**
```bash
# 1. Check pod status
kubectl get pods -n conveyor-pipeline -l app=processor

# 2. View recent logs
kubectl logs -n conveyor-pipeline -l app=processor --tail=100

# 3. Check consumer group lag
kubectl exec -n conveyor-pipeline kafka-0 -- kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --group data-processor-group \
  --describe

# 4. Test InfluxDB connectivity
kubectl exec -n conveyor-pipeline -l app=processor -- curl -k https://influxdb-service:8086/health
```

**Resolution:**
- **Self-Healing:** Kubernetes automatically restarts failed pods
- **Manual Restart:** `kubectl delete pod -n conveyor-pipeline <processor-pod-name>`
- **Check Secrets:** Verify `INFLUXDB_TOKEN` is correctly configured
- **Check Kafka:** Ensure Kafka is running and accessible
- **Escalation:** Check InfluxDB connectivity, review SSL/TLS configuration

**Expected Recovery Time:** 10-30 seconds (plus time to catch up on message backlog)

---

### Scenario 3: Kafka StatefulSet Failure

**Symptoms:**
- Kafka pod not running
- Both producer and processor show connection errors
- Kafka service unavailable

**Diagnosis Steps:**
```bash
# 1. Check Kafka pod status
kubectl get pods -n conveyor-pipeline -l app=kafka

# 2. View Kafka logs
kubectl logs -n conveyor-pipeline kafka-0 --tail=200

# 3. Check StatefulSet status
kubectl describe statefulset kafka -n conveyor-pipeline

# 4. Check persistent volume
kubectl get pvc -n conveyor-pipeline | grep kafka
```

**Resolution:**
- **Self-Healing:** StatefulSet automatically recreates failed pod with same identity (kafka-0)
- **Manual Restart:** `kubectl delete pod -n conveyor-pipeline kafka-0`
- **Check PVC:** Ensure persistent volume claim is bound
- **Check Resources:** Verify node has sufficient CPU/memory
- **Escalation:** If StatefulSet fails to recreate pod, check PVC binding and storage class

**Expected Recovery Time:** 30-60 seconds (Kafka startup time)

**Important Notes:**
- StatefulSet preserves pod identity and storage
- Kafka data persists across pod restarts
- Consumer groups resume from last committed offset

---

### Scenario 4: InfluxDB StatefulSet Failure

**Symptoms:**
- InfluxDB pod not running
- Processor shows write errors
- Grafana datasource disconnected

**Diagnosis Steps:**
```bash
# 1. Check InfluxDB pod status
kubectl get pods -n conveyor-pipeline -l app=influxdb

# 2. View InfluxDB logs
kubectl logs -n conveyor-pipeline influxdb-0 --tail=200

# 3. Check StatefulSet and PVC
kubectl describe statefulset influxdb -n conveyor-pipeline
kubectl get pvc -n conveyor-pipeline | grep influxdb

# 4. Test HTTPS endpoint
kubectl exec -n conveyor-pipeline influxdb-0 -- curl -k https://localhost:8086/health
```

**Resolution:**
- **Self-Healing:** StatefulSet automatically recreates failed pod
- **Manual Restart:** `kubectl delete pod -n conveyor-pipeline influxdb-0`
- **Check TLS Certificates:** Verify influxdb-tls secret exists
- **Check Storage:** Ensure PVC is bound and has available space
- **Escalation:** Check TLS certificate validity, review storage capacity

**Expected Recovery Time:** 30-60 seconds

---

### Scenario 5: High Resource Usage / HPA Scaling

**Symptoms:**
- CPU/Memory usage exceeds limits
- Pods showing `OOMKilled` status
- HPA triggers scale-up events

**Diagnosis Steps:**
```bash
# 1. Check resource usage
kubectl top pods -n conveyor-pipeline

# 2. Check HPA status
kubectl get hpa -n conveyor-pipeline
kubectl describe hpa producer-hpa -n conveyor-pipeline

# 3. View scaling events
kubectl get events -n conveyor-pipeline --sort-by='.lastTimestamp' | grep HorizontalPodAutoscaler
```

**Resolution:**
- **Automatic Scaling:** HPA automatically increases replica count
- **Monitor Scaling:** Watch `kubectl get hpa -n conveyor-pipeline --watch`
- **Manual Scaling:** `kubectl scale deployment producer -n conveyor-pipeline --replicas=3`
- **Adjust Limits:** If OOMKilled occurs frequently, increase memory limits in deployment
- **Escalation:** Review resource requests/limits, consider node scaling

**Expected Behavior:**
- Scale-up occurs when CPU > 70% for 15 seconds
- Scale-down occurs after 5 minutes of low usage
- Maximum replicas: 5

---

### Scenario 6: Network Policy Issues

**Symptoms:**
- Pods unable to communicate despite being Running
- Connection timeouts in logs
- Services unreachable

**Diagnosis Steps:**
```bash
# 1. Check network policies
kubectl get networkpolicies -n conveyor-pipeline

# 2. Test connectivity between pods
kubectl exec -n conveyor-pipeline -l app=producer -- nc -zv kafka-service 9092
kubectl exec -n conveyor-pipeline -l app=processor -- curl -k https://influxdb-service:8086/health

# 3. Check service endpoints
kubectl get endpoints -n conveyor-pipeline
```

**Resolution:**
- **Verify Network Policies:** Ensure policies allow required traffic
- **Check Service DNS:** Test DNS resolution inside pods
- **Review Security Groups:** Check if cluster network policies block traffic
- **Escalation:** Review NetworkPolicy manifests, consult cluster administrator

---

## 4. Troubleshooting Workflow

```
┌─────────────────────────┐
│ Detect Issue            │
│ (Monitoring/Alerts)     │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Identify Failed         │
│ Component               │
│ (kubectl get pods)      │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Check Logs & Events     │
│ (kubectl logs/describe) │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐      ┌──────────────────┐
│ Is pod self-healing?    │─Yes─→│ Monitor recovery │
└───────────┬─────────────┘      └──────────────────┘
            │ No
            ▼
┌─────────────────────────┐
│ Manual Intervention     │
│ (delete pod/restart)    │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐      ┌──────────────────┐
│ Issue resolved?         │─Yes─→│ Document incident│
└───────────┬─────────────┘      └──────────────────┘
            │ No
            ▼
┌─────────────────────────┐
│ Escalate to DevOps      │
│ (deeper investigation)  │
└─────────────────────────┘
```

---

## 5. Preventive Maintenance

### Weekly Tasks
- Review pod restart counts: `kubectl get pods -n conveyor-pipeline`
- Check persistent volume usage: `kubectl exec -n conveyor-pipeline influxdb-0 -- df -h`
- Review Grafana metrics trends
- Test backup/restore procedures

### Monthly Tasks
- Review resource requests/limits based on actual usage
- Update Docker images with latest security patches
- Review and rotate secrets (InfluxDB tokens, TLS certificates)
- Load testing to validate HPA behavior

---

## 6. Emergency Contacts & Escalation

### L1 - Operator (You)
- Handle routine restarts
- Monitor dashboards
- Follow runbooks
- Document incidents

### L2 - DevOps Engineer
- Complex troubleshooting
- Configuration changes
- Resource scaling
- TLS/Security issues

### L3 - Platform Team
- Cluster-level issues
- Storage problems
- Network policies
- Performance optimization

---

## 7. Testing Self-Healing

To verify Kubernetes self-healing capabilities, run:

```bash
cd CA3
bash scripts/resilience-test.sh
```

This script tests:
1. Producer pod deletion → automatic restart
2. Processor pod deletion → automatic restart
3. Kafka StatefulSet recovery → pod recreation with persistent data

**Expected Results:**
- All pods recover within 30-60 seconds
- Data pipeline resumes normal operation
- No data loss (Kafka retains messages, InfluxDB preserves data)

---

## 8. Key Metrics to Monitor

| Metric | Tool | Threshold | Action |
|--------|------|-----------|--------|
| Producer rate | Grafana | > 0.5 msg/s | Normal operation |
| Processor rate | Grafana | Matches producer | Normal consumption |
| InfluxDB writes | Grafana | Matches processor | Data being persisted |
| Pod restarts | `kubectl get pods` | < 5 restarts | Investigate if excessive |
| CPU usage | `kubectl top pods` | < 80% sustained | Consider scaling |
| Memory usage | `kubectl top pods` | < 90% sustained | Check for memory leaks |
| HPA replicas | `kubectl get hpa` | 1-5 replicas | Verify autoscaling works |

---

## 9. Known Issues & Workarounds

### Issue 1: InfluxDB Self-Signed Certificate Warnings
- **Symptom:** Processor logs show `InsecureRequestWarning`
- **Impact:** Cosmetic warning, does not affect functionality
- **Workaround:** Acceptable for development; use proper CA-signed cert in production

### Issue 2: Kafka Rebalancing Delays
- **Symptom:** Processor shows "Re-joining group" messages after restart
- **Impact:** Brief 5-10 second delay before consuming resumes
- **Workaround:** Normal Kafka behavior, no action needed

### Issue 3: HPA Metrics Lag
- **Symptom:** HPA shows stale CPU metrics for 15-30 seconds
- **Impact:** Slight delay in autoscaling decisions
- **Workaround:** Metrics-server scrape interval is 15s, this is expected

---

## 10. Useful Commands Cheat Sheet

```bash
# Quick health check
kubectl get all -n conveyor-pipeline

# Watch pods in real-time
kubectl get pods -n conveyor-pipeline --watch

# Get logs from all producer pods
kubectl logs -n conveyor-pipeline -l app=producer --tail=50 --all-containers=true

# Port-forward to Grafana
kubectl port-forward -n conveyor-pipeline svc/grafana-service 3000:3000

# Port-forward to Prometheus
kubectl port-forward -n conveyor-pipeline svc/prometheus-service 9090:9090

# Get events sorted by time
kubectl get events -n conveyor-pipeline --sort-by='.lastTimestamp'

# Restart deployment (rolling restart)
kubectl rollout restart deployment producer -n conveyor-pipeline

# Scale deployment manually
kubectl scale deployment producer -n conveyor-pipeline --replicas=3

# Execute command in pod
kubectl exec -it -n conveyor-pipeline <pod-name> -- /bin/sh

# Copy files from pod
kubectl cp conveyor-pipeline/<pod-name>:/path/to/file ./local-file

# Delete pod (triggers recreate)
kubectl delete pod -n conveyor-pipeline <pod-name>
```

---

## Summary

This document provides comprehensive procedures for operating the CA3 IoT data pipeline. Key principles:

1. **Trust Kubernetes Self-Healing:** Most failures resolve automatically
2. **Monitor Proactively:** Use Grafana, Loki, and kubectl to detect issues early
3. **Follow Runbooks:** Systematic diagnosis prevents oversight
4. **Document Everything:** Record incidents for pattern analysis
5. **Test Regularly:** Run resilience tests to validate recovery procedures

For questions or complex issues, escalate to DevOps or Platform teams.
