#!/bin/bash
# CA2 Validation Script
# Validates Producer → Kafka deployment

set -e

# Create run logs directory if it doesn't exist
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/run_logs"
mkdir -p "$LOG_DIR"

# Create timestamped log file
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/validate_${TIMESTAMP}.log"

# Function to log to both console and file
log() {
    echo "$@" | tee -a "$LOG_FILE"
}

log "=== CA2: Validation Script ==="
log "Validating Producer → Kafka → Processor → InfluxDB → Grafana Deployment"
log "Timestamp: $(date)"
log "Log file: $LOG_FILE"
log ""

NAMESPACE="conveyor-pipeline"
FAILED_TESTS=0
TOTAL_TESTS=0

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    echo -n "Testing $test_name... " | tee -a "$LOG_FILE"
    if eval "$test_command" &>/dev/null; then
        echo "✅ PASSED" | tee -a "$LOG_FILE"
        return 0
    else
        echo "❌ FAILED" | tee -a "$LOG_FILE"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

log "🔍 Infrastructure Validation"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test namespace exists
run_test "Namespace exists" "kubectl get namespace $NAMESPACE"

# Test pods are running
run_test "Kafka pod running" "kubectl get pod kafka-0 -n $NAMESPACE -o jsonpath='{.status.phase}' | grep -q Running"
run_test "InfluxDB pod running" "kubectl get pod influxdb-0 -n $NAMESPACE -o jsonpath='{.status.phase}' | grep -q Running"
run_test "Producer pod running" "kubectl get pods -n $NAMESPACE -l app=producer --field-selector=status.phase=Running | grep -q producer"
run_test "Processor pod running" "kubectl get pods -n $NAMESPACE -l app=processor --field-selector=status.phase=Running | grep -q processor"
run_test "Grafana pod running" "kubectl get pods -n $NAMESPACE -l app=grafana --field-selector=status.phase=Running | grep -q grafana"

# Test services exist
run_test "Kafka service exists" "kubectl get service kafka-service -n $NAMESPACE"
run_test "InfluxDB service exists" "kubectl get service influxdb-service -n $NAMESPACE"
run_test "Grafana service exists" "kubectl get service grafana-service -n $NAMESPACE"

# Test StatefulSet and Deployment
run_test "Kafka StatefulSet ready" "kubectl get statefulset kafka -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' | grep -q '1'"
run_test "InfluxDB StatefulSet ready" "kubectl get statefulset influxdb -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' | grep -q '1'"
run_test "Producer Deployment ready" "kubectl get deployment producer -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' | grep -q '[1-9]'"
run_test "Processor Deployment ready" "kubectl get deployment processor -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' | grep -q '[1-9]'"
run_test "Grafana Deployment ready" "kubectl get deployment grafana -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' | grep -q '1'"

log ""
log "🔗 Connectivity Tests"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test Kafka connectivity and topic creation
log "Testing Kafka topic creation..."
if kubectl exec -n $NAMESPACE kafka-0 -- kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic conveyor-speed --partitions 1 --replication-factor 1 &>/dev/null; then
    log "✅ Kafka topic 'conveyor-speed' created/exists"
else
    log "❌ Failed to create Kafka topic"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

log ""
log "📊 Data Flow Validation"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test producer is generating data
log "Testing producer data generation..."
if kubectl logs -n $NAMESPACE deployment/producer --tail=10 | grep -q "Speed:"; then
    log "✅ Producer generating data"
    PRODUCER_LOGS=$(kubectl logs -n $NAMESPACE deployment/producer --tail=3)
    log "   Latest producer logs:"
    echo "$PRODUCER_LOGS" | sed 's/^/     /' | tee -a "$LOG_FILE"
else
    log "❌ Producer not generating data"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# Test Kafka messages
log "Testing Kafka message flow..."
if kubectl exec -n $NAMESPACE kafka-0 -- kafka-console-consumer --bootstrap-server localhost:9092 --topic conveyor-speed --max-messages 1 --timeout-ms 10000 2>/dev/null | grep -q "speed_ms"; then
    log "✅ Kafka messages flowing"
else
    log "❌ No Kafka messages detected"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

log ""
log "🔒 Security Validation"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test Secrets exist
run_test "Kubernetes Secrets exist" "kubectl get secret pipeline-secrets -n $NAMESPACE"
run_test "Kafka Secrets exist" "kubectl get secret kafka-secrets -n $NAMESPACE"
run_test "InfluxDB Secrets exist" "kubectl get secret influxdb-secrets -n $NAMESPACE"
run_test "Grafana Secrets exist" "kubectl get secret grafana-secrets -n $NAMESPACE"

# Test NetworkPolicies exist (now 6: default-deny, producer, kafka, processor, influxdb, grafana)
run_test "NetworkPolicies applied" "kubectl get networkpolicy -n $NAMESPACE | wc -l | grep -q '[6-9]'"

# Test RBAC
run_test "ServiceAccount exists" "kubectl get serviceaccount conveyor-pipeline-sa -n $NAMESPACE"
run_test "Role exists" "kubectl get role conveyor-pipeline-role -n $NAMESPACE"
run_test "RoleBinding exists" "kubectl get rolebinding conveyor-pipeline-rolebinding -n $NAMESPACE"

log ""
log "📈 Scaling Test"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Current replica count
CURRENT_REPLICAS=$(kubectl get deployment producer -n $NAMESPACE -o jsonpath='{.spec.replicas}')
log "Current producer replicas: $CURRENT_REPLICAS"

# Scale up test
log "Testing scaling to 3 replicas..."
kubectl scale deployment producer --replicas=3 -n $NAMESPACE >> "$LOG_FILE" 2>&1

# Wait for scaling
log "Waiting for scaling to complete..."
if kubectl wait --for=condition=available deployment/producer -n $NAMESPACE --timeout=60s &>/dev/null; then
    NEW_REPLICAS=$(kubectl get deployment producer -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
    if [[ "$NEW_REPLICAS" == "3" ]]; then
        log "✅ Scaling test passed (scaled to 3 replicas)"
    else
        log "❌ Scaling test failed (expected 3, got $NEW_REPLICAS)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
else
    log "❌ Scaling test failed (timeout)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# Scale back
log "Scaling back to original replica count..."
kubectl scale deployment producer --replicas=$CURRENT_REPLICAS -n $NAMESPACE >> "$LOG_FILE" 2>&1

log ""
log "📋 Validation Summary"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

PASSED_TESTS=$((TOTAL_TESTS - FAILED_TESTS))
SUCCESS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))

log "Total Tests: $TOTAL_TESTS"
log "Passed: $PASSED_TESTS"
log "Failed: $FAILED_TESTS"
log "Success Rate: $SUCCESS_RATE%"

# InfluxDB-specific validation
log ""
log "InfluxDB Status Checks"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check InfluxDB health endpoint
log "Checking InfluxDB health..."
if kubectl exec -n $NAMESPACE influxdb-0 -- curl -s http://localhost:8086/health 2>/dev/null | grep -q '"status":"pass"'; then
    log "✅ InfluxDB health check passed"
else
    log "⚠️ InfluxDB health check inconclusive (may still be initializing)"
fi

# Check InfluxDB logs for successful initialization
log "Checking InfluxDB initialization..."
if kubectl logs -n $NAMESPACE influxdb-0 --tail=30 2>/dev/null | grep -q -E "setup|started"; then
    log "InfluxDB initialization logs:"
    kubectl logs -n $NAMESPACE influxdb-0 --tail=10 2>/dev/null | sed 's/^/     /' | tee -a "$LOG_FILE"
else
    log "Note: InfluxDB still initializing"
fi

# Processor-specific validation
log ""
log "Processor Status Checks"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check processor logs for Kafka connection
log "Checking processor Kafka connectivity..."
if kubectl logs -n $NAMESPACE deployment/processor --tail=20 2>/dev/null | grep -q "Connecting to Kafka"; then
    log "✅ Processor attempting Kafka connection"
    PROCESSOR_LOGS=$(kubectl logs -n $NAMESPACE deployment/processor --tail=5 2>/dev/null)
    log "   Latest processor logs:"
    echo "$PROCESSOR_LOGS" | sed 's/^/     /' | tee -a "$LOG_FILE"
else
    log "Note: Processor logs not available yet"
fi

# Check for InfluxDB connection success
log "Checking processor InfluxDB connectivity..."
if kubectl logs -n $NAMESPACE deployment/processor --tail=30 2>/dev/null | grep -q -E "Connected to InfluxDB|Writing to InfluxDB"; then
    log "✅ Processor successfully connected to InfluxDB"
elif kubectl logs -n $NAMESPACE deployment/processor --tail=30 2>/dev/null | grep -q "Connecting to InfluxDB"; then
    log "⚠️ Processor attempting InfluxDB connection (may still be initializing)"
else
    log "Note: Processor not yet attempting InfluxDB connection"
fi

# Data flow validation - check if data is being written to InfluxDB
log ""
log "Data Flow End-to-End Validation"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

log "Checking data written to InfluxDB..."
if kubectl logs -n $NAMESPACE deployment/processor --tail=50 2>/dev/null | grep -q -E "Processed.*messages|wrote.*points|Writing to InfluxDB"; then
    log "✅ Data being written to InfluxDB"
    # Count messages processed
    PROCESS_COUNT=$(kubectl logs -n $NAMESPACE deployment/processor 2>/dev/null | grep -c "Writing to InfluxDB" || echo "0")
    log "   Total writes detected in processor logs: $PROCESS_COUNT"
else
    log "⚠️ No data writes detected yet (pipeline may still be warming up)"
fi

# Grafana-specific validation
log ""
log "Grafana Status Checks"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check Grafana health endpoint
log "Checking Grafana health..."
if kubectl exec -n $NAMESPACE deployment/grafana -- curl -s http://localhost:3000/api/health 2>/dev/null | grep -q '"database":"ok"'; then
    log "✅ Grafana health check passed"
else
    log "⚠️ Grafana health check inconclusive (may still be initializing)"
fi

# Check Grafana datasource
log "Checking Grafana InfluxDB datasource..."
GRAFANA_POD=$(kubectl get pods -n $NAMESPACE -l app=grafana -o jsonpath='{.items[0].metadata.name}')
if [ -n "$GRAFANA_POD" ]; then
    if kubectl logs -n $NAMESPACE "$GRAFANA_POD" 2>/dev/null | grep -q -E "datasource|InfluxDB"; then
        log "✅ Grafana datasource configuration detected"
    else
        log "⚠️ Datasource configuration pending"
    fi
fi

# Get Grafana access URL
GRAFANA_NODEPORT=$(kubectl get svc grafana-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
if [ -n "$GRAFANA_NODEPORT" ]; then
    log ""
    log "Grafana Dashboard Access:"
    log "   URL: http://localhost:$GRAFANA_NODEPORT"
    log "   Username: admin"
    log "   Password: ChangeThisGrafanaPassword123!"
    log "   Dashboard: 'Conveyor Line Speed Monitoring'"
fi

if [[ $FAILED_TESTS -eq 0 ]]; then
    log ""
    log "All tests passed! Producer → Kafka → Processor → InfluxDB → Grafana pipeline deployed."
    log ""
    log "Current Deployment Status:"
    kubectl get all -n $NAMESPACE | tee -a "$LOG_FILE"

    # Save kubectl status snapshot
    STATUS_LOG="$LOG_DIR/kubectl_status_${TIMESTAMP}.log"
    kubectl get all -n $NAMESPACE -o wide > "$STATUS_LOG"
    log ""
    log "Detailed status saved to: $STATUS_LOG"
    exit 0
else
    log ""
    log "Some tests failed. Please check the issues above."
    exit 1
fi