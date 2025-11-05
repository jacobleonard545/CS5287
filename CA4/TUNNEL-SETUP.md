# SSH Tunnel Setup for CA4

## Problem: Grafana Has No Data

**Root Cause**: The producer cannot send messages to Kafka because there's no SSH tunnel connecting your local machine to AWS.

**Current Status**:
- ✅ Producer pod running on local Kubernetes
- ✅ AWS containers running (Kafka, Processor, InfluxDB, Grafana)
- ❌ No SSH tunnel = Producer cannot reach Kafka
- ❌ No data flowing = Empty Grafana dashboard

## Solution: Establish SSH Tunnel

### Option 1: PowerShell or Windows Terminal (RECOMMENDED)

Open a **NEW PowerShell or Windows Terminal** window and run:

```powershell
ssh -i C:\Users\J14Le\.ssh\ca4-key `
    -L 9092:localhost:9092 `
    -L 8086:localhost:8086 `
    -L 3000:localhost:3000 `
    -L 8001:localhost:8000 `
    -N ubuntu@3.148.242.194
```

**Important**:
- Keep this window open while using CA4
- The command will appear to hang - this is normal
- Don't press Ctrl+C unless you want to close the tunnel

### Option 2: Use Direct Access (Workaround)

Since Git Bash has SSH tunnel issues, you can:

1. **Access Grafana directly** (already working):
   ```
   http://3.148.242.194:3000
   ```

2. **Update producer to use AWS public IP** instead of tunnel:

   Edit `CA4/k8s/edge/producer-configmap.yaml`:
   ```yaml
   KAFKA_BROKER: "3.148.242.194:9092"
   ```

   **BUT**: This requires opening port 9092 in AWS security group (not secure)

### Option 3: WSL (Windows Subsystem for Linux)

If you have WSL installed:

```bash
wsl
cd /mnt/c/Users/J14Le/CS5287/CA4
ssh -i ~/.ssh/ca4-key \
    -L 9092:localhost:9092 \
    -L 8086:localhost:8086 \
    -L 3000:localhost:3000 \
    -L 8001:localhost:8000 \
    -N ubuntu@3.148.242.194
```

## Verification Steps

### 1. Check if Tunnel is Running

In a separate terminal:

```powershell
# Check if SSH process exists
Get-Process | Where-Object {$_.ProcessName -eq "ssh"}

# Test Kafka connectivity
Test-NetConnection -ComputerName localhost -Port 9092
```

### 2. Verify Producer Connects to Kafka

After establishing tunnel:

```bash
# Wait 30 seconds for producer to retry connection
kubectl logs -f -l app=producer -n conveyor-pipeline-edge
```

**Expected**: Messages like "Published message to Kafka"

### 3. Verify Data in InfluxDB

```bash
ssh -i C:\Users\J14Le\.ssh\ca4-key ubuntu@3.148.242.194 `
    "sudo docker exec influxdb influx query 'from(bucket:\"conveyor-data\") |> range(start: -5m) |> limit(n:5)'"
```

**Expected**: Rows of conveyor speed data

### 4. Check Grafana Dashboard

Open: http://3.148.242.194:3000
- Login: admin / (password from .env.cloud or ChangeThisGrafanaPassword123!)
- Dashboard: "Conveyor Line Speed Monitoring"
- **Expected**: Line graph with speed data

## Troubleshooting

### Tunnel Keeps Disconnecting
```powershell
# Add keep-alive options
ssh -i C:\Users\J14Le\.ssh\ca4-key `
    -o ServerAliveInterval=60 `
    -o ServerAliveCountMax=3 `
    -L 9092:localhost:9092 `
    -L 8086:localhost:8086 `
    -L 3000:localhost:3000 `
    -L 8001:localhost:8000 `
    -N ubuntu@3.148.242.194
```

### Producer Still Can't Connect
1. Check tunnel is running (ps/Get-Process)
2. Test port: `telnet localhost 9092` or `Test-NetConnection localhost -Port 9092`
3. Restart producer pod:
   ```bash
   kubectl delete pod -n conveyor-pipeline-edge --all
   kubectl get pods -n conveyor-pipeline-edge --watch
   ```

### Port Already in Use
```powershell
# Find process using port 9092
netstat -ano | findstr :9092

# Kill the process (replace PID)
taskkill /PID <process_id> /F
```

## Current System IPs

- **AWS Public IP**: 3.148.242.194
- **Local Kubernetes**: Uses host.docker.internal → localhost:9092
- **SSH Tunnel Mapping**:
  - localhost:9092 → AWS Kafka
  - localhost:8086 → AWS InfluxDB
  - localhost:3000 → AWS Grafana
  - localhost:8001 → AWS Processor

## Quick Fix Script (PowerShell)

Save this as `start-tunnel.ps1`:

```powershell
# CA4 SSH Tunnel Starter
Write-Host "Starting SSH tunnel to AWS..." -ForegroundColor Green
Write-Host "Keep this window open!" -ForegroundColor Yellow

$keyPath = "C:\Users\J14Le\.ssh\ca4-key"
$awsIP = "3.148.242.194"

ssh -i $keyPath `
    -o ServerAliveInterval=60 `
    -o ServerAliveCountMax=3 `
    -L 9092:localhost:9092 `
    -L 8086:localhost:8086 `
    -L 3000:localhost:3000 `
    -L 8001:localhost:8000 `
    -N ubuntu@$awsIP
```

Run: `powershell -ExecutionPolicy Bypass -File start-tunnel.ps1`
