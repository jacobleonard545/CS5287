# t2.micro Optimization Guide

## Performance Tuning for 1 vCPU, 1GB RAM

To run the Kafka data pipeline on t2.micro instances (keeping the required 4 VMs), we need to optimize each service for minimal resource usage:

## Memory Optimizations

### 1. Kafka Service Optimization
```yaml
# In kafka-compose.yml
environment:
  KAFKA_HEAP_OPTS: "-Xmx256m -Xms128m"
  KAFKA_JVM_PERFORMANCE_OPTS: "-XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35"
```

### 2. MongoDB Optimization
```yaml
# In mongodb-compose.yml
command: ["mongod", "--wiredTigerCacheSizeGB", "0.25", "--nojournal"]
```

### 3. Java Processor Optimization
```yaml
# In processor-compose.yml
environment:
  JAVA_OPTS: "-Xmx128m -Xms64m -XX:+UseSerialGC"
```

### 4. Memory Limits in Docker Compose
```yaml
services:
  kafka:
    mem_limit: 512m
  mongodb:
    mem_limit: 256m
  processor:
    mem_limit: 128m
  producer:
    mem_limit: 64m
```

## System-Level Optimizations

### 1. Swap Configuration
```bash
# On each VM, create swap space
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### 2. Kernel Parameters
```bash
# Add to /etc/sysctl.conf
vm.swappiness=10
vm.overcommit_memory=1
net.core.somaxconn=1024
```

### 3. Docker Optimization
```bash
# Add to /etc/docker/daemon.json
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

## Cost Comparison

### Option 1: Assignment Compliant (Higher Performance)
- **kafka-vm**: t2.medium ($0.0464/hour) 
- **mongodb-vm**: t2.medium ($0.0464/hour)
- **processor-vm**: t2.small ($0.0232/hour)
- **producer-vm**: t2.small ($0.0232/hour)
- **Total**: ~$0.14/hour (~$100/month)

### Option 2: t2.micro Optimized (Free Tier Eligible)
- **kafka-vm**: t2.micro (Free tier: 750 hours/month)
- **mongodb-vm**: t2.micro (Free tier: 750 hours/month)
- **processor-vm**: t2.micro (Free tier: 750 hours/month) 
- **producer-vm**: t2.micro (Free tier: 750 hours/month)
- **Total**: $0/month (within free tier limits)

## Performance Expectations on t2.micro

### Expected Limitations:
- **Throughput**: ~100-500 messages/second (vs 10K+ on larger instances)
- **Startup Time**: 2-3x longer container startup
- **Memory Pressure**: Occasional swapping under load
- **CPU Credits**: May throttle under sustained load

### Mitigation Strategies:
1. **Reduce Message Size**: Keep messages under 1KB
2. **Batch Processing**: Process in smaller batches
3. **Monitoring**: Watch for CPU credit depletion
4. **Graceful Degradation**: Handle slower processing in code

## Deployment Scripts

### For t2.micro deployment:
```bash
# Use the original aws-infrastructure.sh (already updated to t2.micro)
./aws-infrastructure.sh
```

### Start services with optimized configurations:
```bash
# On kafka-vm
docker-compose -f kafka-compose.yml up -d

# On mongodb-vm
docker-compose -f mongodb-compose.yml up -d

# On processor-vm
docker-compose -f processor-compose.yml up -d

# On producer-vm
docker-compose -f producer-compose.yml up -d
```

## Monitoring Resource Usage

```bash
# Check memory usage
free -h
docker stats

# Check CPU credits (for t2 instances)
aws cloudwatch get-metric-statistics \
    --namespace AWS/EC2 \
    --metric-name CPUCreditBalance \
    --dimensions Name=InstanceId,Value=i-1234567890abcdef0 \
    --statistics Average \
    --start-time 2024-01-01T00:00:00Z \
    --end-time 2024-01-01T23:59:59Z \
    --period 3600
```

## Recommendation

**For Assignment Submission**: Use the assignment-compliant t2.medium/small configuration to ensure stable performance during demo.

**For Personal Learning**: Use t2.micro with optimizations to stay within free tier.

Both configurations meet the assignment requirements of 4 VMs running the complete data pipeline.