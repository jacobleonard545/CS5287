#!/bin/bash
# CA2 Deployment Script
# Deploys Producer → Kafka pipeline to Kubernetes

set -e

echo "=== CA2: Full Pipeline Deployment ==="
echo "Deploying Producer → Kafka → Processor → InfluxDB → Grafana"
echo ""

NAMESPACE="conveyor-pipeline"

# Check prerequisites
echo "Checking prerequisites..."
if ! command -v kubectl &> /dev/null; then
    echo "ERROR: kubectl not found. Please install kubectl."
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo "ERROR: No Kubernetes cluster connection. Please ensure cluster is accessible."
    exit 1
fi

echo "Prerequisites check passed"
echo ""

# Get current context
CONTEXT=$(kubectl config current-context)
echo "Deploying to context: $CONTEXT"
echo ""

# Deploy in order
echo "Deploying components..."

echo "1. Creating namespace..."
kubectl apply -f k8s/namespace.yaml

echo "2. Setting up RBAC..."
kubectl apply -f k8s/rbac.yaml

echo "3. Applying secrets..."
kubectl apply -f k8s/secrets.yaml

echo "4. Deploying Kafka StatefulSet..."
kubectl apply -f k8s/kafka/

echo "5. Deploying InfluxDB StatefulSet..."
kubectl apply -f k8s/influxdb/

echo "6. Deploying Processor..."
kubectl apply -f k8s/processor/

echo "7. Deploying Producer..."
kubectl apply -f k8s/producer/

echo "8. Deploying Grafana..."
kubectl apply -f k8s/grafana/

echo "9. Applying Network Policies..."
kubectl apply -f k8s/network/

echo "10. Deploying Prometheus..."
kubectl apply -f k8s/prometheus/prometheus-rbac.yaml
kubectl apply -f k8s/prometheus/prometheus-configmap.yaml
kubectl apply -f k8s/prometheus/prometheus-deployment.yaml
kubectl apply -f k8s/prometheus/prometheus-service.yaml
kubectl apply -f k8s/prometheus/prometheus-network-policy.yaml

echo ""
echo "Waiting for Kafka to be ready..."
kubectl wait --for=condition=ready pod -l app=kafka -n $NAMESPACE --timeout=180s

echo ""
echo "Waiting for InfluxDB to be ready..."
kubectl wait --for=condition=ready pod -l app=influxdb -n $NAMESPACE --timeout=180s

echo ""
echo "Waiting for Processor to be ready..."
kubectl wait --for=condition=available deployment/processor -n $NAMESPACE --timeout=120s

echo ""
echo "Waiting for Producer to be ready..."
kubectl wait --for=condition=available deployment/producer -n $NAMESPACE --timeout=120s

echo ""
echo "Waiting for Grafana to be ready..."
kubectl wait --for=condition=available deployment/grafana -n $NAMESPACE --timeout=120s

echo ""
echo "Waiting for Prometheus to be ready..."
kubectl wait --for=condition=available deployment/prometheus -n $NAMESPACE --timeout=120s

echo ""
echo "Deployment completed!"
echo ""

# Display status
echo "Deployment Status:"
kubectl get all -n $NAMESPACE

echo ""
echo "Useful Commands:"
echo "View producer logs: kubectl logs -f deployment/producer -n $NAMESPACE"
echo "View processor logs: kubectl logs -f deployment/processor -n $NAMESPACE"
echo "View kafka logs: kubectl logs -f statefulset/kafka -n $NAMESPACE"
echo "View influxdb logs: kubectl logs -f statefulset/influxdb -n $NAMESPACE"
echo "View grafana logs: kubectl logs -f deployment/grafana -n $NAMESPACE"
echo "View prometheus logs: kubectl logs -f deployment/prometheus -n $NAMESPACE"
echo "Scale producers: kubectl scale deployment producer --replicas=3 -n $NAMESPACE"
echo "Test kafka messages: kubectl exec -it kafka-0 -n $NAMESPACE -- kafka-console-consumer --bootstrap-server localhost:9092 --topic conveyor-speed --from-beginning"

echo ""
echo "Pipeline deployed! Data flows: Producer → Kafka → Processor → InfluxDB → Grafana"
echo ""

# Get Grafana access information
GRAFANA_NODEPORT=$(kubectl get svc grafana-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')
echo "=== GRAFANA DASHBOARD ACCESS ==="
echo "URL: http://localhost:$GRAFANA_NODEPORT"
echo "Username: admin"
echo "Password: ChangeThisGrafanaPassword123!"
echo ""
echo "Dashboard: 'Conveyor Line Speed Monitoring'"
echo "Alternative access: kubectl port-forward -n $NAMESPACE svc/grafana-service 3000:3000"
echo ""
echo "=== PROMETHEUS ACCESS ==="
echo "Port-forward: kubectl port-forward -n $NAMESPACE svc/prometheus-service 9090:9090"
echo "Then access: http://localhost:9090"