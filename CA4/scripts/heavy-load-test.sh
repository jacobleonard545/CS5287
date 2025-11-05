#!/bin/bash
# Heavy Load Test - Scale to Maximum (5 pods)
# Generates sustained high CPU load to trigger full HPA scaling

set -e

NAMESPACE="conveyor-pipeline"
DEPLOYMENT="producer"
DURATION=${1:-300}  # Default 5 minutes to allow multiple scale steps

echo "=========================================="
echo "CA3 Heavy Load Test - Scale to Maximum"
echo "=========================================="
echo "Namespace: $NAMESPACE"
echo "Target: Scale from 1 to 5 pods"
echo "Duration: ${DURATION}s"
echo "=========================================="
echo ""

# Check initial state
echo "[$(date '+%H:%M:%S')] Initial State:"
kubectl get hpa -n $NAMESPACE
kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT
echo ""

# Get all current producer pods
PRODUCER_PODS=$(kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT -o jsonpath='{.items[*].metadata.name}')

echo "[$(date '+%H:%M:%S')] Starting HEAVY CPU load..."
echo "Generating maximum CPU stress on all producer pods..."
echo ""

# Generate very high CPU load on all pods
for POD in $PRODUCER_PODS; do
    echo "Stressing pod: $POD with 8 CPU-intensive processes"
    kubectl exec -n $NAMESPACE $POD -- sh -c "
        # Generate 8 infinite loops to max out CPU
        for i in 1 2 3 4 5 6 7 8; do
            (while true; do echo; done) &
        done
        sleep ${DURATION}
        # Kill all background jobs
        pkill -P \$\$
    " &
done

echo ""
echo "[$(date '+%H:%M:%S')] Heavy load running for ${DURATION}s"
echo ""
echo "=== Monitor Scaling ==="
echo "Watch HPA scale up:"
echo "  kubectl get hpa -n $NAMESPACE --watch"
echo ""
echo "Watch pods being created:"
echo "  watch 'kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT'"
echo ""
echo "Watch CPU usage:"
echo "  watch 'kubectl top pods -n $NAMESPACE -l app=$DEPLOYMENT'"
echo ""

# Monitor scaling progress
for i in {1..20}; do
    sleep 15
    echo "[$(date '+%H:%M:%S')] Status Update #$i:"
    kubectl get hpa -n $NAMESPACE
    echo ""
    kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT | grep -v "Terminating" || true
    echo ""
    kubectl top pods -n $NAMESPACE -l app=$DEPLOYMENT 2>/dev/null || echo "Metrics not ready yet"
    echo "---"
done

echo ""
echo "[$(date '+%H:%M:%S')] Load test completed!"
echo ""
echo "Final State:"
kubectl get hpa -n $NAMESPACE
kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT
echo ""
echo "Scale-down will occur after 5-minute cooldown"
echo "=========================================="
