#!/bin/bash
# CA2 Cleanup Script
# Destroys Producer → Kafka pipeline from Kubernetes

set -e

echo "=== CA2: Cleanup Script ==="
echo "Destroying Producer → Kafka → Processor Pipeline"
echo ""

NAMESPACE="conveyor-pipeline"

# Check if namespace exists
if ! kubectl get namespace $NAMESPACE &>/dev/null; then
    echo "❌ Namespace $NAMESPACE does not exist. Nothing to clean up."
    exit 0
fi

echo "🔍 Current resources in namespace $NAMESPACE:"
kubectl get all -n $NAMESPACE

echo ""
echo "⚠️  WARNING: This will permanently delete all CA2 resources!"
echo ""
echo "This includes:"
echo "  • Producer deployment and pods"
echo "  • Processor deployment and pods"
echo "  • Kafka StatefulSet and persistent volumes"
echo "  • All services and network policies"
echo "  • All configmaps, secrets, and RBAC"
echo "  • The entire namespace"
echo ""

read -p "Are you sure you want to proceed? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "🗑️  Proceeding with cleanup..."

# Delete in reverse order
echo "1. Removing NetworkPolicies..."
kubectl delete networkpolicy --all -n $NAMESPACE 2>/dev/null || true

echo "2. Removing Deployments..."
kubectl delete deployment --all -n $NAMESPACE 2>/dev/null || true

echo "3. Removing StatefulSets..."
kubectl delete statefulset --all -n $NAMESPACE 2>/dev/null || true

echo "4. Removing Services..."
kubectl delete service --all -n $NAMESPACE 2>/dev/null || true

echo "5. Removing ConfigMaps..."
kubectl delete configmap --all -n $NAMESPACE 2>/dev/null || true

echo "6. Removing PersistentVolumeClaims..."
kubectl delete pvc --all -n $NAMESPACE 2>/dev/null || true

echo "7. Removing RBAC..."
kubectl delete role,rolebinding,serviceaccount --all -n $NAMESPACE 2>/dev/null || true

echo "8. Removing HPA..."
kubectl delete hpa --all -n $NAMESPACE 2>/dev/null || true

echo "9. Removing Namespace..."
kubectl delete namespace $NAMESPACE 2>/dev/null || true

echo ""
echo "⏳ Waiting for complete cleanup..."
# Wait for namespace to be fully deleted
while kubectl get namespace $NAMESPACE &>/dev/null; do
    echo "   Waiting for namespace deletion..."
    sleep 3
done

echo ""
echo "✅ Cleanup completed successfully!"
echo ""
echo "📊 Verification:"
if kubectl get namespace $NAMESPACE &>/dev/null; then
    echo "❌ Namespace still exists"
    kubectl get all -n $NAMESPACE
else
    echo "✅ Namespace completely removed"
fi

echo ""
echo "🧹 CA2 resources have been cleaned up!"