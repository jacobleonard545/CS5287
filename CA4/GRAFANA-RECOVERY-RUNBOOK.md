# Grafana Failure & Recovery Runbook

## Overview
This runbook documents the procedure for detecting, diagnosing, and recovering from Grafana dashboard failures in the CA4 Multi-Hybrid Cloud deployment.

---

## Failure Scenario: Grafana Container Down

### Symptoms
- Dashboard URL (http://3.148.242.194:3000) returns connection refused or timeout
- Unable to visualize conveyor line monitoring data
- HTTP health checks failing

---

## Pre-Drill: Verify Normal State

### 1. Check Grafana Accessibility
```bash
curl -I http://3.148.242.194:3000
```
**Expected Output:** HTTP 302 (redirect to login) or HTTP 200

### 2. Check Container Status
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker ps | grep grafana"
```
**Expected Output:**
```
grafana     Up X hours     0.0.0.0:3000->3000/tcp
```

### 3. Access Dashboard
- Open browser: http://3.148.242.194:3000
- Login with credentials
- Verify "Conveyor Line Speed Monitoring" dashboard shows all 4 lines with live data

### 4. Document Baseline
- Take screenshot of healthy dashboard
- Note timestamp: `date '+%Y-%m-%d %H:%M:%S'`

---

## Failure Injection

### Step 1: Stop Grafana Container
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker stop grafana"
```

**Record timestamp of failure:**
```bash
echo "Failure injected at: $(date '+%Y-%m-%d %H:%M:%S')"
```

### Step 2: Verify Failure State

**Check container status:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker ps -a | grep grafana"
```
**Expected:** Container shows "Exited" status

**Test HTTP endpoint:**
```bash
curl -I http://3.148.242.194:3000
```
**Expected:** Connection refused or timeout

**Try accessing dashboard in browser:**
- Should show connection error or "This site can't be reached"

---

## Impact Assessment

### What Still Works
✅ **Edge Producers** - Continue generating data (Kubernetes pods unaffected)
✅ **Kafka** - Messages still queued
✅ **Processor** - Still consuming from Kafka
✅ **InfluxDB** - Data continues to be written
✅ **Data Pipeline** - Fully operational, only visualization affected

### What's Affected
❌ **Dashboard Visibility** - Cannot view real-time metrics
❌ **Historical Queries** - Cannot explore past data through UI
❌ **Alerts** - Grafana-based alerting disabled (if configured)

### Key Insight
**Data loss:** NONE - InfluxDB continues storing all data. Grafana is purely a visualization layer.

---

## Recovery Procedures

### Option 1: Automatic Recovery (Docker Restart Policy)

**Check restart policy:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker inspect grafana | grep -A 5 RestartPolicy"
```

If `restart: unless-stopped` is configured (which it is in docker-compose-cloud.yml), the container should automatically restart.

**Wait 5-10 seconds and verify:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker ps | grep grafana"
```

---

### Option 2: Manual Recovery - Restart Container

**If automatic recovery doesn't occur, manually restart:**

```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker restart grafana"
```

**Record recovery timestamp:**
```bash
echo "Manual restart initiated at: $(date '+%Y-%m-%d %H:%M:%S')"
```

**Monitor startup:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker logs -f grafana --tail 20"
```

**Look for:**
```
HTTP Server Listen=[::]::3000
```

Press `Ctrl+C` to exit logs once started.

---

### Option 3: Full Recovery via Docker Compose

**If container is corrupted or restart fails:**

```bash
# Navigate to deployment directory
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "cd ~ && sudo docker-compose -f docker-compose-cloud.yml restart grafana"
```

**Or stop and recreate:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "cd ~ && sudo docker-compose -f docker-compose-cloud.yml up -d grafana"
```

---

## Verification Steps

### 1. Check Container Health
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker ps | grep grafana"
```
**Expected:** Status shows "Up" with uptime

### 2. Test HTTP Endpoint
```bash
curl -I http://3.148.242.194:3000
```
**Expected:** HTTP 302 or HTTP 200

### 3. Verify Dashboard Access
- Open browser: http://3.148.242.194:3000
- Login with admin credentials
- Navigate to "Conveyor Line Speed Monitoring" dashboard

### 4. Confirm Data Continuity
- Check that dashboard shows continuous data
- Verify all 4 conveyor lines (line_1, line_2, line_3, line_4) are visible
- Confirm time series shows data throughout the outage period
- **Key observation:** No data gaps should exist (data was stored in InfluxDB during Grafana downtime)

### 5. Calculate Recovery Time
```bash
# If you noted start and end times
echo "Recovery time: [end_time] - [start_time]"
```

**Typical recovery time:** 5-15 seconds

---

## Post-Recovery Actions

### 1. Document Incident
Create entry in incident log:
```
Date/Time: [timestamp]
Component: Grafana Dashboard
Failure Type: Container stopped
Impact: Visualization unavailable, no data loss
Recovery Method: [Automatic/Manual restart]
Recovery Time: [X seconds]
Root Cause: [Intentional failure injection / unexpected crash / resource issue]
```

### 2. Verify Related Services
```bash
# Check all cloud services
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker ps --format 'table {{.Names}}\t{{.Status}}'"
```

### 3. Review Logs for Errors
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker logs grafana --tail 50 | grep -i error"
```

---

## Troubleshooting

### Issue: Container Won't Start

**Check logs:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker logs grafana --tail 100"
```

**Common causes:**
- Port 3000 already in use
- Volume mount issues
- Insufficient memory
- Configuration errors

**Solution - Check port:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo netstat -tlnp | grep 3000"
```

**Solution - Check memory:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "free -h"
```

---

### Issue: Dashboard Shows No Data After Recovery

**Verify InfluxDB is running:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker ps | grep influxdb"
```

**Test InfluxDB connection:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "curl -k https://localhost:8086/health"
```

**Check Grafana datasource configuration:**
- Login to Grafana
- Go to Configuration → Data Sources
- Click "InfluxDB-ConveyorData"
- Click "Save & Test"
- Should show "datasource is working"

---

### Issue: Dashboards Missing After Recovery

**Provisioned dashboards should auto-load from:**
```
~/grafana-provisioning/dashboards/conveyor-monitoring.json
```

**Verify volume mount:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker inspect grafana | grep -A 10 Mounts"
```

**Should show:**
```
./grafana-provisioning/dashboards:/etc/grafana/provisioning/dashboards
```

**If dashboards missing, restart with clean state:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "cd ~ && sudo docker-compose -f docker-compose-cloud.yml restart grafana"
```

---

## Prevention & Best Practices

### 1. Resource Monitoring
- Monitor container memory usage: `docker stats grafana`
- Set memory limits in docker-compose (currently 256MB limit, 128MB reserved)

### 2. Regular Backups
**Backup Grafana configuration:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker exec grafana tar -czf /tmp/grafana-backup.tar.gz /var/lib/grafana"
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker cp grafana:/tmp/grafana-backup.tar.gz ~/grafana-backup-$(date +%Y%m%d).tar.gz"
```

### 3. Health Check Monitoring
```bash
# Add to cron or monitoring system
curl -f http://3.148.242.194:3000/api/health || echo "Grafana down"
```

### 4. Restart Policy
Ensure docker-compose.yml has:
```yaml
grafana:
  restart: unless-stopped
```

---

## Expected Recovery Time Objectives

| Metric | Target | Typical |
|--------|--------|---------|
| **Detection Time** | < 1 minute | Immediate (manual test) |
| **Automatic Restart** | < 15 seconds | 5-10 seconds |
| **Manual Restart** | < 30 seconds | 10-20 seconds |
| **Full Recovery (including verification)** | < 2 minutes | 30-60 seconds |
| **Data Loss** | 0% | 0% (data stored in InfluxDB) |

---

## Extended Troubleshooting: Full Data Pipeline

### Architecture Overview
```
[Edge] Producer Pods (K8s) → [Cloud] Kafka → Processor → InfluxDB → Grafana
```

---

## Component 1: Producer (Edge - Kubernetes)

### Symptoms of Producer Failure
- No new data appearing in Grafana dashboard
- Specific conveyor line(s) missing from dashboard
- Kafka topic has no recent messages

### Detection Commands

**Check all producer pods:**
```bash
kubectl get pods -n conveyor-pipeline-edge
```

**Check specific pod logs:**
```bash
kubectl logs -n conveyor-pipeline-edge <pod-name> --tail=50
```

**Check pod events:**
```bash
kubectl describe pod -n conveyor-pipeline-edge <pod-name>
```

### Common Producer Issues

#### Issue 1: Pod CrashLoopBackOff

**Diagnosis:**
```bash
kubectl describe pod -n conveyor-pipeline-edge <pod-name> | grep -A 10 Events
kubectl logs -n conveyor-pipeline-edge <pod-name> --previous
```

**Common Causes:**
- Cannot connect to Kafka (network/DNS issue)
- Invalid environment variables
- Image pull failure

**Recovery:**
```bash
# Delete pod - Kubernetes will recreate it
kubectl delete pod -n conveyor-pipeline-edge <pod-name>

# If deployment issue, restart deployment
kubectl rollout restart deployment producer -n conveyor-pipeline-edge
kubectl rollout restart deployment producer-line2 -n conveyor-pipeline-edge
kubectl rollout restart deployment producer-line3 -n conveyor-pipeline-edge
kubectl rollout restart deployment producer-line4 -n conveyor-pipeline-edge
```

#### Issue 2: Pod Running but Not Publishing

**Diagnosis:**
```bash
# Check pod logs for Kafka connection errors
kubectl logs -n conveyor-pipeline-edge <pod-name> --tail=100 | grep -i error

# Check if pod can reach Kafka
kubectl exec -n conveyor-pipeline-edge <pod-name> -- nc -zv 3.148.242.194 9092
```

**Common Causes:**
- Kafka broker down
- Network connectivity issue
- Kafka authentication failure

**Recovery:**
```bash
# Verify Kafka is running (see Kafka section below)
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker ps | grep kafka"

# Restart producer pod
kubectl delete pod -n conveyor-pipeline-edge <pod-name>
```

#### Issue 3: All Producers Down

**Diagnosis:**
```bash
kubectl get pods -n conveyor-pipeline-edge
# All pods show ImagePullBackOff, CrashLoopBackOff, or Error
```

**Recovery:**
```bash
# Check namespace exists
kubectl get namespace conveyor-pipeline-edge

# Check ConfigMap
kubectl get configmap -n conveyor-pipeline-edge producer-config

# Recreate all deployments
kubectl apply -f CA4/k8s/edge/producer-deployment.yaml
kubectl apply -f CA4/k8s/edge/producer-line2-deployment.yaml
kubectl apply -f CA4/k8s/edge/producer-line3-deployment.yaml
kubectl apply -f CA4/k8s/edge/producer-line4-deployment.yaml
```

### Producer Recovery Time
- **Pod restart:** 10-15 seconds
- **Automatic recreation:** 15-30 seconds
- **Data loss:** None (Kafka queues messages)

---

## Component 2: Kafka (Cloud - Docker)

### Symptoms of Kafka Failure
- All producers unable to publish
- Processor cannot consume messages
- Connection refused on port 9092

### Detection Commands

**Check Kafka container:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker ps | grep kafka"
```

**Check Kafka logs:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker logs kafka --tail=100"
```

**Test Kafka connectivity:**
```bash
# From edge
nc -zv 3.148.242.194 9092

# From cloud (internal)
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker exec kafka kafka-broker-api-versions --bootstrap-server localhost:9092"
```

### Common Kafka Issues

#### Issue 1: Kafka Container Down

**Diagnosis:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker ps -a | grep kafka"
# Shows "Exited" status
```

**Recovery:**
```bash
# Restart Kafka
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker restart kafka"

# Or via docker-compose
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "cd ~ && sudo docker-compose -f docker-compose-cloud.yml restart kafka"

# Monitor startup
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker logs -f kafka"
```

**Wait for:** `[KafkaServer id=1] started`

#### Issue 2: Kafka Out of Memory

**Diagnosis:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker stats kafka --no-stream"
# Memory usage at or near limit (384MB)

ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker logs kafka | grep -i 'OutOfMemory\|OOM'"
```

**Recovery:**
```bash
# Restart Kafka to clear memory
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker restart kafka"

# If persistent, increase memory limit in docker-compose-cloud.yml
# Then recreate container
```

#### Issue 3: Kafka Topic Issues

**List topics:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list"
```

**Check topic details:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker exec kafka kafka-topics --bootstrap-server localhost:9092 --describe --topic conveyor-speed"
```

**Recreate topic if corrupted:**
```bash
# Delete topic (WARNING: loses queued messages)
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker exec kafka kafka-topics --bootstrap-server localhost:9092 --delete --topic conveyor-speed"

# Recreate topic
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker exec kafka kafka-topics --bootstrap-server localhost:9092 --create --topic conveyor-speed --partitions 3 --replication-factor 1"
```

#### Issue 4: Port 9092 Not Accessible

**Diagnosis:**
```bash
# Check if port is listening
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo netstat -tlnp | grep 9092"

# Check AWS security group
aws ec2 describe-security-groups --group-ids <security-group-id> | grep -A 5 "9092"
```

**Recovery:**
```bash
# If security group issue, add ingress rule
aws ec2 authorize-security-group-ingress \
  --group-id <sg-id> \
  --protocol tcp \
  --port 9092 \
  --cidr 0.0.0.0/0
```

### Kafka Recovery Time
- **Container restart:** 10-20 seconds
- **Full startup:** 20-30 seconds
- **Data loss:** Minimal (messages in memory buffer may be lost)

---

## Component 3: Processor (Cloud - Docker)

### Symptoms of Processor Failure
- Kafka has messages but InfluxDB doesn't receive data
- Dashboard shows stale data (no recent updates)
- Processor container stopped

### Detection Commands

**Check processor container:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker ps | grep processor"
```

**Check processor logs:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker logs processor --tail=100"
```

**Verify Kafka consumer lag:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker exec kafka kafka-consumer-groups --bootstrap-server localhost:9092 --describe --group conveyor-processor-group"
```

### Common Processor Issues

#### Issue 1: Processor Container Down

**Diagnosis:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker ps -a | grep processor"
# Shows "Exited" status
```

**Recovery:**
```bash
# Restart processor
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker restart processor"

# Monitor startup
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker logs -f processor"
```

**Look for:** `Starting consumer...` and `Processing messages...`

#### Issue 2: Processor Cannot Connect to Kafka

**Diagnosis:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker logs processor | grep -i 'kafka\|connection\|error'"
```

**Recovery:**
```bash
# Verify Kafka is running
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker ps | grep kafka"

# Check Docker network
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker network inspect ca4-network"

# Restart processor to reconnect
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker restart processor"
```

#### Issue 3: Processor Cannot Write to InfluxDB

**Diagnosis:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker logs processor | grep -i 'influx\|write\|error'"
```

**Common errors:**
- `unauthorized access` - Invalid token
- `connection refused` - InfluxDB down
- `certificate` - TLS/SSL issue

**Recovery:**
```bash
# Verify InfluxDB is running
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker ps | grep influxdb"

# Check InfluxDB health
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "curl -k https://localhost:8086/health"

# Verify environment variables
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker exec processor printenv | grep INFLUX"

# Restart processor
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker restart processor"
```

#### Issue 4: Consumer Lag Building Up

**Diagnosis:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker exec kafka kafka-consumer-groups --bootstrap-server localhost:9092 --describe --group conveyor-processor-group"
# Check LAG column - should be low (< 100)
```

**Causes:**
- Processor too slow
- InfluxDB write bottleneck
- High message volume

**Recovery:**
```bash
# Check processor resource usage
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker stats processor --no-stream"

# Restart to clear any issues
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker restart processor"

# If persistent, may need to scale processor (add replicas)
```

### Processor Recovery Time
- **Container restart:** 5-10 seconds
- **Kafka reconnection:** 5-15 seconds
- **Data loss:** None (Kafka preserves messages)

---

## Component 4: InfluxDB (Cloud - Docker)

### Symptoms of InfluxDB Failure
- Processor errors writing data
- Grafana shows "data source not found"
- No new data in dashboard

### Detection Commands

**Check InfluxDB container:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker ps | grep influxdb"
```

**Check InfluxDB health:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "curl -k https://localhost:8086/health"
```

**Check InfluxDB logs:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker logs influxdb --tail=100"
```

### Common InfluxDB Issues

#### Issue 1: InfluxDB Container Down

**Diagnosis:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker ps -a | grep influxdb"
# Shows "Exited" status
```

**Recovery:**
```bash
# Restart InfluxDB
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker restart influxdb"

# Monitor startup
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker logs -f influxdb"
```

**Wait for:** `Listening on https://[::]:8086`

#### Issue 2: InfluxDB Out of Disk Space

**Diagnosis:**
```bash
# Check disk usage on EC2
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "df -h"

# Check volume usage
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo du -sh /var/lib/docker/volumes/ubuntu_influxdb-data"
```

**Recovery:**
```bash
# Delete old data (adjust retention policy)
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker exec influxdb influx delete \
  --bucket conveyor-data \
  --start 1970-01-01T00:00:00Z \
  --stop $(date -d '7 days ago' -u +%Y-%m-%dT%H:%M:%SZ) \
  --org VanderbiltU \
  --token \$DOCKER_INFLUXDB_INIT_ADMIN_TOKEN"

# Or increase EC2 EBS volume size
```

#### Issue 3: Authentication Failure

**Diagnosis:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker logs influxdb | grep -i 'unauthorized\|auth\|token'"
```

**Recovery:**
```bash
# Check token in environment
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker exec influxdb printenv DOCKER_INFLUXDB_INIT_ADMIN_TOKEN"

# Verify token matches in processor and grafana
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker exec processor printenv INFLUXDB_TOKEN"
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker exec grafana printenv INFLUXDB_TOKEN"

# If mismatch, update .env.cloud and recreate containers
```

#### Issue 4: TLS Certificate Issues

**Diagnosis:**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker logs influxdb | grep -i 'tls\|certificate\|ssl'"
```

**Recovery:**
```bash
# Check certificate files exist
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "ls -la ~/tls-certs/"

# Verify certificate validity
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker exec influxdb openssl x509 -in /etc/ssl/influxdb/tls.crt -text -noout | grep 'Not After'"

# Regenerate certificates if expired
cd CA4/k8s/tls
bash generate-influxdb-certs.sh

# Copy to server
scp -i ~/.ssh/ca4-key CA4/tls-certs/* ubuntu@3.148.242.194:~/tls-certs/

# Restart InfluxDB
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker restart influxdb"
```

#### Issue 5: Data Corruption

**Diagnosis:**
```bash
# Query returns errors
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker exec influxdb influx query \
  'from(bucket: \"conveyor-data\") |> range(start: -5m)' \
  --org VanderbiltU \
  --token \$DOCKER_INFLUXDB_INIT_ADMIN_TOKEN"
```

**Recovery (NUCLEAR OPTION - loses all data):**
```bash
# Stop InfluxDB
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker-compose -f docker-compose-cloud.yml stop influxdb"

# Remove volume
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker volume rm ubuntu_influxdb-data"

# Recreate with fresh database
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker-compose -f docker-compose-cloud.yml up -d influxdb"
```

### InfluxDB Recovery Time
- **Container restart:** 10-20 seconds
- **Full startup:** 15-30 seconds
- **Data loss:** None (unless volume corrupted/deleted)

---

## Multi-Component Failure Scenarios

### Scenario 1: Complete Cloud Stack Down

**Symptoms:**
- All cloud containers stopped
- Producers show connection errors
- Nothing visible in Grafana

**Recovery:**
```bash
# Restart entire cloud stack
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "cd ~ && sudo docker-compose -f docker-compose-cloud.yml restart"

# Or start individual components in order
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "cd ~ && \
  sudo docker-compose -f docker-compose-cloud.yml start kafka && \
  sleep 10 && \
  sudo docker-compose -f docker-compose-cloud.yml start influxdb && \
  sleep 10 && \
  sudo docker-compose -f docker-compose-cloud.yml start processor && \
  sudo docker-compose -f docker-compose-cloud.yml start grafana"
```

**Recovery Time:** 1-2 minutes for full stack

---

### Scenario 2: Network Partition (Edge-to-Cloud)

**Symptoms:**
- Producers cannot reach Kafka
- Cloud services running but no data ingestion

**Diagnosis:**
```bash
# Test connectivity from edge
nc -zv 3.148.242.194 9092

# Check AWS security group
aws ec2 describe-security-groups --filters "Name=group-name,Values=*kafka*"

# Check EC2 instance status
aws ec2 describe-instances --instance-ids <instance-id>
```

**Recovery:**
```bash
# Verify security group allows port 9092
# Restart Kafka if needed
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker restart kafka"

# Producers will auto-reconnect
```

---

### Scenario 3: Data Pipeline Blocked

**Symptoms:**
- Producers publishing
- Kafka receiving messages
- InfluxDB not getting data
- Grafana shows stale data

**Diagnosis:**
```bash
# Check processor status
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker ps | grep processor"

# Check consumer lag
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker exec kafka kafka-consumer-groups --bootstrap-server localhost:9092 --describe --group conveyor-processor-group"

# Check processor logs
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker logs processor --tail=50"
```

**Recovery:**
```bash
# Restart processor
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker restart processor"

# Verify InfluxDB is accessible
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "curl -k https://localhost:8086/health"
```

---

## Complete System Health Check Script

Save this as `health-check.sh`:

```bash
#!/bin/bash

echo "=== CA4 System Health Check ==="
echo "Timestamp: $(date)"
echo ""

echo "--- Edge Producers (Kubernetes) ---"
kubectl get pods -n conveyor-pipeline-edge
echo ""

echo "--- Cloud Components (Docker) ---"
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker ps --format 'table {{.Names}}\t{{.Status}}\t{{Ports}}'"
echo ""

echo "--- Kafka Health ---"
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker exec kafka kafka-broker-api-versions --bootstrap-server localhost:9092" > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✓ Kafka is responding"
else
  echo "✗ Kafka is not responding"
fi
echo ""

echo "--- InfluxDB Health ---"
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "curl -sk https://localhost:8086/health" | grep -q "pass"
if [ $? -eq 0 ]; then
  echo "✓ InfluxDB is healthy"
else
  echo "✗ InfluxDB is not healthy"
fi
echo ""

echo "--- Grafana Health ---"
curl -s -o /dev/null -w "%{http_code}" http://3.148.242.194:3000 | grep -q "200\|302"
if [ $? -eq 0 ]; then
  echo "✓ Grafana is accessible"
else
  echo "✗ Grafana is not accessible"
fi
echo ""

echo "--- Consumer Lag ---"
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker exec kafka kafka-consumer-groups --bootstrap-server localhost:9092 --describe --group conveyor-processor-group 2>/dev/null"
echo ""

echo "=== Health Check Complete ==="
```

---

## Summary

**Grafana Role:** Visualization and query interface only
**Critical Dependency:** InfluxDB (data source)
**Impact of Failure:** Dashboard unavailable, but no data loss
**Recovery Method:** Automatic via Docker restart policy, or manual restart
**Recovery Time:** Typically 5-15 seconds
**Data Continuity:** Complete (InfluxDB continues storing data during outage)

---

## Video Demonstration Script

### Setup (Before Recording)
1. Open browser to Grafana dashboard
2. Have terminal ready with SSH connection
3. Open second terminal for monitoring

### Demo Flow (2-3 minutes)

**Scene 1: Show Healthy State (15 seconds)**
- Show dashboard with 4 conveyor lines updating
- "Here's the Grafana dashboard showing real-time data from all 4 conveyor lines"

**Scene 2: Inject Failure (10 seconds)**
```bash
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker stop grafana"
```
- "I'm stopping the Grafana container to simulate a dashboard failure"
- Refresh browser → Show connection error

**Scene 3: Show Impact (15 seconds)**
```bash
# Show other services still running
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker ps"
```
- "Notice: Kafka, Processor, and InfluxDB are still running"
- "Data is still being collected and stored, we just can't visualize it"

**Scene 4: Recovery (30 seconds)**
```bash
# Manual restart
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker restart grafana"

# Watch it come back
ssh -i ~/.ssh/ca4-key ubuntu@3.148.242.194 "sudo docker ps | grep grafana"
```
- "Restarting Grafana with Docker restart command"
- "Container is back up in about 10 seconds"

**Scene 5: Verification (30 seconds)**
- Refresh browser → Dashboard loads
- "Dashboard is accessible again"
- "Notice there's NO GAP in the data - InfluxDB kept storing measurements"
- "All 4 conveyor lines show continuous data throughout the outage"

**Conclusion (10 seconds)**
- "Total recovery time: ~15 seconds"
- "Zero data loss - visualization layer is separate from data storage"

---

## Contact Information

**AWS Instance:** 3.148.242.194
**SSH Key:** ~/.ssh/ca4-key
**Grafana Port:** 3000
**Admin Credentials:** [Stored in .env.cloud]

---

**Document Version:** 1.0
**Last Updated:** 2025-11-05
**Owner:** Cloud Operations Team
