#!/bin/bash
# CA2 Container Image Build Script
# Builds producer image for Producer → Kafka setup

set -e

echo "=== CA2: Building Container Images ==="
echo ""

# Configuration
# Use DOCKER_REGISTRY environment variable or default to local username
DOCKER_REGISTRY="${DOCKER_REGISTRY:-$(whoami)}"
PRODUCER_IMAGE="$DOCKER_REGISTRY/conveyor-producer"
PROCESSOR_IMAGE="$DOCKER_REGISTRY/conveyor-processor"
TAG="${1:-latest}"

echo "Configuration:"
echo "Registry: $DOCKER_REGISTRY"
echo "Producer image: $PRODUCER_IMAGE:$TAG"
echo "Processor image: $PROCESSOR_IMAGE:$TAG"
echo ""

# Check prerequisites
echo "Checking prerequisites..."
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker not found. Please install Docker."
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "ERROR: Docker daemon not running. Please start Docker."
    exit 1
fi

echo "Prerequisites check passed"
echo ""

# Build producer image
echo "Building producer image..."
cd docker/producer
docker build -t $PRODUCER_IMAGE:$TAG .
echo "Producer image built: $PRODUCER_IMAGE:$TAG"
cd ../..

# Build processor image
echo ""
echo "Building processor image..."
cd docker/processor
docker build -t $PROCESSOR_IMAGE:$TAG .
echo "Processor image built: $PROCESSOR_IMAGE:$TAG"
cd ../..

echo ""
echo "Built images:"
docker images | grep "conveyor-"

echo ""
echo "Images ready for deployment!"
echo ""
echo "Next steps:"
echo "1. Optional: Push to registry"
echo "   docker push $PRODUCER_IMAGE:$TAG"
echo "   docker push $PROCESSOR_IMAGE:$TAG"
echo "2. Deploy to Kubernetes with './scripts/deploy.sh'"