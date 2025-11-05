#!/bin/bash
# Load Test Script for CA3 - HPA Validation
# Generates high CPU load on producer pods to trigger autoscaling

set -e

NAMESPACE="conveyor-pipeline"
DEPLOYMENT="producer"
DURATION=${1:-180}  # Default 3 minutes

echo "=========================================="
echo "CA3 Load Test - HPA Validation"
echo "=========================================="
echo "Namespace: $NAMESPACE"
echo "Target: $DEPLOYMENT"
echo "Duration: ${DURATION}s"
echo "=========================================="
echo ""

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting load test..."
echo ""

# Check current state
echo "Current HPA status:"
kubectl get hpa -n $NAMESPACE
echo ""

echo "Current pod count:"
kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT
echo ""

# Create a temporary pod that will stress the producer by sending it signals
# to work harder (simulated by creating CPU load)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Generating CPU load on producer pods..."
echo "This will trigger HPA to scale up the deployment..."
echo ""

# Get producer pod names
PRODUCER_PODS=$(kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT -o jsonpath='{.items[*].metadata.name}')

# Start stress test in background for each producer pod
for POD in $PRODUCER_PODS; do
    echo "Starting CPU stress on pod: $POD"
    kubectl exec -n $NAMESPACE $POD -- sh -c "
        echo 'Generating CPU load...'
        for i in \$(seq 1 4); do
            (while true; do echo; done) &
        done
        sleep ${DURATION}
        pkill -P \$\$
    " &
done

echo ""
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Load test running for ${DURATION} seconds..."
echo "Monitor with:"
echo "  kubectl get hpa -n $NAMESPACE --watch"
echo "  kubectl top pods -n $NAMESPACE"
echo "  kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT --watch"
echo ""

# Wait for test duration
sleep $DURATION

echo ""
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Load test completed!"
echo ""

echo "Final HPA status:"
kubectl get hpa -n $NAMESPACE
echo ""

echo "Final pod count:"
kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT
echo ""

echo "HPA will scale down after cooldown period (~5 minutes)"
echo "=========================================="
