#!/bin/bash
# Script to update Docker registry in Kubernetes manifests
# Usage: ./set-registry.sh <registry-name>

set -e

if [ -z "$1" ]; then
    echo "Usage: ./set-registry.sh <registry-name>"
    echo ""
    echo "Example: ./set-registry.sh myusername"
    echo "This will update image references to myusername/conveyor-producer:latest"
    exit 1
fi

REGISTRY="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Setting Docker Registry ==="
echo "Registry: $REGISTRY"
echo ""

# Update producer deployment
PRODUCER_FILE="$PROJECT_DIR/k8s/producer/producer-deployment.yaml"
if [ -f "$PRODUCER_FILE" ]; then
    echo "Updating producer deployment..."
    sed -i.bak "s|image: .*/conveyor-producer:|image: $REGISTRY/conveyor-producer:|g" "$PRODUCER_FILE"
    rm -f "$PRODUCER_FILE.bak"
fi

# Update processor deployment
PROCESSOR_FILE="$PROJECT_DIR/k8s/processor/processor-deployment.yaml"
if [ -f "$PROCESSOR_FILE" ]; then
    echo "Updating processor deployment..."
    sed -i.bak "s|image: .*/conveyor-processor:|image: $REGISTRY/conveyor-processor:|g" "$PROCESSOR_FILE"
    rm -f "$PROCESSOR_FILE.bak"
fi

echo ""
echo "Docker registry updated to: $REGISTRY"
echo ""
echo "Next steps:"
echo "1. Build images with: DOCKER_REGISTRY=$REGISTRY ./scripts/build-images.sh"
echo "2. Deploy with: ./scripts/deploy.sh"
