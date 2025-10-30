#!/bin/bash

# resilience-test.sh - Automated failure injection and recovery testing
# Demonstrates Kubernetes self-healing capabilities

set -e

NAMESPACE="conveyor-pipeline"
WATCH_DURATION=30

echo "=========================================="
echo "CA3 Resilience Testing Script"
echo "=========================================="
echo "This script will:"
echo "  1. Delete producer pod and observe recovery"
echo "  2. Delete processor pod and observe recovery"
echo "  3. Delete Kafka pod and observe StatefulSet recovery"
echo ""
echo "Namespace: $NAMESPACE"
echo "Watch duration per test: ${WATCH_DURATION}s"
echo "=========================================="
echo ""

# Function to display pod status
show_pods() {
    echo ""
    echo "Current pod status:"
    kubectl get pods -n $NAMESPACE -o wide
    echo ""
}

# Function to wait for pod to be ready
wait_for_pod_ready() {
    local app_label=$1
    local timeout=60

    echo "Waiting for pod with label app=$app_label to be ready..."
    kubectl wait --for=condition=ready pod -l app=$app_label -n $NAMESPACE --timeout=${timeout}s
    echo "✅ Pod is ready!"
}

# Function to show recent logs
show_logs() {
    local app_label=$1
    local pod_name=$(kubectl get pods -n $NAMESPACE -l app=$app_label -o jsonpath='{.items[0].metadata.name}')

    if [ -n "$pod_name" ]; then
        echo ""
        echo "Recent logs from $pod_name:"
        kubectl logs -n $NAMESPACE $pod_name --tail=10 2>&1 || echo "  (Logs not yet available)"
        echo ""
    fi
}

echo "=========================================="
echo "TEST 1: Producer Pod Failure & Recovery"
echo "=========================================="
echo ""

echo "Step 1: Show current producer pod status"
show_pods

echo "Step 2: Get producer pod name"
PRODUCER_POD=$(kubectl get pods -n $NAMESPACE -l app=producer -o jsonpath='{.items[0].metadata.name}')
echo "Producer pod: $PRODUCER_POD"
echo ""

echo "Step 3: Delete producer pod"
kubectl delete pod $PRODUCER_POD -n $NAMESPACE
echo "✅ Producer pod deleted"
echo ""

echo "Step 4: Watch recovery (${WATCH_DURATION}s)"
sleep 5
show_pods
echo "Waiting for new producer pod to be ready..."
wait_for_pod_ready "producer"

echo "Step 5: Verify producer is functioning"
show_logs "producer"

echo "✅ TEST 1 COMPLETE: Producer recovered successfully"
echo ""
sleep 5

echo "=========================================="
echo "TEST 2: Processor Pod Failure & Recovery"
echo "=========================================="
echo ""

echo "Step 1: Show current processor pod status"
show_pods

echo "Step 2: Get processor pod name"
PROCESSOR_POD=$(kubectl get pods -n $NAMESPACE -l app=processor -o jsonpath='{.items[0].metadata.name}')
echo "Processor pod: $PROCESSOR_POD"
echo ""

echo "Step 3: Delete processor pod"
kubectl delete pod $PROCESSOR_POD -n $NAMESPACE
echo "✅ Processor pod deleted"
echo ""

echo "Step 4: Watch recovery (${WATCH_DURATION}s)"
sleep 5
show_pods
echo "Waiting for new processor pod to be ready..."
wait_for_pod_ready "processor"

echo "Step 5: Verify processor is functioning"
show_logs "processor"

echo "✅ TEST 2 COMPLETE: Processor recovered successfully"
echo ""
sleep 5

echo "=========================================="
echo "TEST 3: Kafka StatefulSet Recovery"
echo "=========================================="
echo ""

echo "Step 1: Show current Kafka pod status"
show_pods

echo "Step 2: Get Kafka pod name"
KAFKA_POD=$(kubectl get pods -n $NAMESPACE -l app=kafka -o jsonpath='{.items[0].metadata.name}')
echo "Kafka pod: $KAFKA_POD"
echo ""

echo "Step 3: Delete Kafka pod"
kubectl delete pod $KAFKA_POD -n $NAMESPACE
echo "✅ Kafka pod deleted"
echo ""

echo "Step 4: Watch StatefulSet recovery (${WATCH_DURATION}s)"
sleep 5
show_pods
echo "Waiting for Kafka StatefulSet to recreate pod..."
wait_for_pod_ready "kafka"

echo "Step 5: Verify Kafka is functioning"
show_logs "kafka"

echo "✅ TEST 3 COMPLETE: Kafka recovered successfully"
echo ""

echo "=========================================="
echo "FINAL STATUS CHECK"
echo "=========================================="
show_pods

echo ""
echo "=========================================="
echo "RESILIENCE TEST SUMMARY"
echo "=========================================="
echo "✅ Producer pod: Self-healing verified"
echo "✅ Processor pod: Self-healing verified"
echo "✅ Kafka StatefulSet: Recovery verified"
echo ""
echo "All components demonstrated successful recovery!"
echo "Kubernetes self-healing capabilities validated."
echo "=========================================="
