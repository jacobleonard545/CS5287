#!/bin/bash
# Generate self-signed TLS certificates for InfluxDB
# CA3 Milestone 7: TLS for InfluxDB

set -e

CERT_DIR="$(dirname "$0")"
NAMESPACE="conveyor-pipeline"

echo "=========================================="
echo "Generating InfluxDB TLS Certificates"
echo "=========================================="
echo ""

# Generate private key
echo "[1/4] Generating private key..."
openssl genrsa -out "$CERT_DIR/influxdb-key.pem" 2048

# Generate certificate signing request
echo "[2/4] Creating certificate signing request..."
openssl req -new -key "$CERT_DIR/influxdb-key.pem" \
    -out "$CERT_DIR/influxdb-csr.pem" \
    -subj "/C=US/ST=Tennessee/L=Nashville/O=VanderbiltU/OU=CS5287/CN=influxdb-service.conveyor-pipeline.svc.cluster.local"

# Generate self-signed certificate (valid for 365 days)
echo "[3/4] Generating self-signed certificate..."
openssl x509 -req -days 365 \
    -in "$CERT_DIR/influxdb-csr.pem" \
    -signkey "$CERT_DIR/influxdb-key.pem" \
    -out "$CERT_DIR/influxdb-cert.pem" \
    -extfile <(printf "subjectAltName=DNS:influxdb-service,DNS:influxdb-service.conveyor-pipeline,DNS:influxdb-service.conveyor-pipeline.svc,DNS:influxdb-service.conveyor-pipeline.svc.cluster.local,DNS:localhost,IP:127.0.0.1")

# Create Kubernetes Secret
echo "[4/4] Creating Kubernetes Secret..."
kubectl create secret generic influxdb-tls \
    --from-file=tls.crt="$CERT_DIR/influxdb-cert.pem" \
    --from-file=tls.key="$CERT_DIR/influxdb-key.pem" \
    --namespace="$NAMESPACE" \
    --dry-run=client -o yaml > "$CERT_DIR/influxdb-tls-secret.yaml"

echo ""
echo "✓ Certificate generated: $CERT_DIR/influxdb-cert.pem"
echo "✓ Private key generated: $CERT_DIR/influxdb-key.pem"
echo "✓ Secret manifest created: $CERT_DIR/influxdb-tls-secret.yaml"
echo ""
echo "Next steps:"
echo "1. Review the secret: cat $CERT_DIR/influxdb-tls-secret.yaml"
echo "2. Apply the secret: kubectl apply -f $CERT_DIR/influxdb-tls-secret.yaml"
echo "3. Update InfluxDB configuration to use TLS"
echo ""
echo "=========================================="
