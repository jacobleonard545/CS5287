# CA3 TLS Configuration Summary

## Milestone 7: TLS for InfluxDB

This document summarizes the TLS encryption implementation for InfluxDB connections in CA3.

## Overview

TLS (Transport Layer Security) has been enabled for all connections to InfluxDB, encrypting data in transit between:
- Processor → InfluxDB (HTTPS)
- Grafana → InfluxDB (HTTPS)

## Implementation Details

### 1. Certificate Generation

**Self-Signed Certificate Created:**
- Certificate file: `k8s/tls/influxdb-cert.pem`
- Private key: `k8s/tls/influxdb-key.pem`
- Valid for: 365 days
- CN: `influxdb-service.conveyor-pipeline.svc.cluster.local`

**Subject Alternative Names (SANs):**
- DNS: influxdb-service
- DNS: influxdb-service.conveyor-pipeline
- DNS: influxdb-service.conveyor-pipeline.svc
- DNS: influxdb-service.conveyor-pipeline.svc.cluster.local  
- DNS: localhost
- IP: 127.0.0.1

### 2. Kubernetes Secret

TLS certificates stored as Kubernetes Secret:
```
Name: influxdb-tls
Namespace: conveyor-pipeline
Type: Opaque
Data:
  tls.crt (certificate)
  tls.key (private key)
```

### 3. InfluxDB Configuration

**StatefulSet Changes:**
- Mounted TLS secret at `/etc/ssl/influxdb`
- Added environment variables:
  - `INFLUXD_TLS_CERT=/etc/ssl/influxdb/tls.crt`
  - `INFLUXD_TLS_KEY=/etc/ssl/influxdb/tls.key`
- Updated health probes to use HTTPS scheme

**Result:**
- InfluxDB now listens on HTTPS (port 8086)
- HTTP connections rejected with TLS handshake error

### 4. Processor Updates

**Changes:**
- Updated `INFLUXDB_URL` from `http://` to `https://`
- Added `verify_ssl=False` to InfluxDBClient (for self-signed cert)
- Rebuilt Docker image: `j14le/conveyor-processor:ca3-metrics-tls`

**Connection Status:**
✅ Successfully writing to InfluxDB over HTTPS
⚠️  InsecureRequestWarning (expected for self-signed certificates)

**Log Evidence:**
```
2025-10-20 15:31:03 - INFO - InfluxDB write #140: speed=0.000m/s, avg=0.017, state=running
2025-10-20 15:31:13 - INFO - InfluxDB write #150: speed=0.024m/s, avg=0.007, state=running
```

### 5. Grafana Updates

**Datasource Configuration:**
- Updated URL from `http://` to `https://`
- Enabled `tlsSkipVerify: true` (self-signed cert)

## Verification

### Processor → InfluxDB (HTTPS)

✅ **Working**
- Processor connecting via HTTPS
- Data writes successful
- SSL warnings present (expected for self-signed cert)

Command to verify:
```bash
kubectl logs -n conveyor-pipeline deployment/processor --tail=20 | grep "InfluxDB write"
```

### InfluxDB TLS Enabled

✅ **Working**
- InfluxDB rejecting HTTP connections
- TLS handshake errors for non-HTTPS clients
- Certificate mounted correctly

Command to verify:
```bash
kubectl logs -n conveyor-pipeline statefulset/influxdb --tail=10 | grep TLS
```

### Data Flow

✅ **Complete Pipeline Working**
```
Producer → Kafka → Processor --(HTTPS)--> InfluxDB → Grafana
```

All components functioning with TLS enabled for InfluxDB connections.

## Security Considerations

### Self-Signed Certificates

**Production Recommendation:**
- Replace self-signed certificates with CA-signed certificates
- Use cert-manager for automatic certificate management
- Enable proper certificate verification

**Current Implementation:**
- Uses `verify_ssl=False` / `tlsSkipVerify=true`  
- Acceptable for development/educational purposes
- NOT recommended for production

### TLS Benefits

✅ **Encryption:** Data encrypted in transit  
✅ **Authentication:** Server identity verification (if using CA certs)  
✅ **Integrity:** Protection against man-in-the-middle attacks

## Files Modified

1. `k8s/tls/generate-influxdb-certs.sh` - Certificate generation script
2. `k8s/tls/openssl.cnf` - OpenSSL configuration
3. `k8s/tls/influxdb-tls-secret.yaml.template` - Secret template
4. `k8s/influxdb/influxdb-statefulset.yaml` - TLS volume mounts
5. `k8s/processor/processor-configmap.yaml` - HTTPS URL
6. `k8s/processor/processor-deployment.yaml` - New image tag
7. `k8s/grafana/grafana-datasource-configmap.yaml` - HTTPS URL  
8. `docker/processor/conveyor_processor.py` - SSL verification disabled

## Testing Commands

```bash
# Verify certificate secret exists
kubectl get secret influxdb-tls -n conveyor-pipeline

# Check InfluxDB TLS logs
kubectl logs -n conveyor-pipeline statefulset/influxdb | grep -i tls

# Verify processor HTTPS connections
kubectl logs -n conveyor-pipeline deployment/processor | grep "InfluxDB write"

# Test InfluxDB health over HTTPS (will fail without --insecure)
kubectl exec -n conveyor-pipeline statefulset/influxdb -- \
  curl -k https://localhost:8086/health
```

## Conclusion

TLS encryption for InfluxDB has been successfully implemented and verified. All connections to InfluxDB now use HTTPS, providing encryption for data in transit.

**Status:** ✅ Milestone 7 Complete
