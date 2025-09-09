#!/bin/bash
# Complete Data Pipeline Monitoring Script
# Usage: ./monitor-pipeline.sh

echo "🚀 Kafka Data Pipeline Monitoring Dashboard"
echo "=========================================="

# VM IPs
KAFKA_VM="18.225.56.119"
MONGODB_VM="3.147.45.147" 
PROCESSOR_VM="18.222.164.197"
PRODUCER_VM="3.133.152.69"
KEY_FILE="kafka-pipeline-key.pem"

echo ""
echo "📊 1. VM STATUS CHECK"
echo "--------------------"
echo "Kafka VM     (${KAFKA_VM}):"
ssh -i $KEY_FILE -o ConnectTimeout=5 ubuntu@$KAFKA_VM "uptime | awk '{print \"  Load:\", \$10, \$11, \$12}'"

echo "MongoDB VM   (${MONGODB_VM}):"
ssh -i $KEY_FILE -o ConnectTimeout=5 ubuntu@$MONGODB_VM "uptime | awk '{print \"  Load:\", \$10, \$11, \$12}'"

echo "Processor VM (${PROCESSOR_VM}):"
ssh -i $KEY_FILE -o ConnectTimeout=5 ubuntu@$PROCESSOR_VM "uptime | awk '{print \"  Load:\", \$10, \$11, \$12}'"

echo "Producer VM  (${PRODUCER_VM}):"
ssh -i $KEY_FILE -o ConnectTimeout=5 ubuntu@$PRODUCER_VM "uptime | awk '{print \"  Load:\", \$10, \$11, \$12}'"

echo ""
echo "🐳 2. DOCKER CONTAINER STATUS"
echo "----------------------------"
echo "Kafka VM containers:"
ssh -i $KEY_FILE ubuntu@$KAFKA_VM "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

echo ""
echo "MongoDB VM containers:"
ssh -i $KEY_FILE ubuntu@$MONGODB_VM "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

echo ""
echo "🔄 3. KAFKA TOPICS & MESSAGES"
echo "-----------------------------"
echo "Available topics:"
ssh -i $KEY_FILE ubuntu@$KAFKA_VM "docker exec kafka-broker kafka-topics --bootstrap-server localhost:9092 --list"

echo ""
echo "Topic details:"
ssh -i $KEY_FILE ubuntu@$KAFKA_VM "docker exec kafka-broker kafka-topics --bootstrap-server localhost:9092 --describe --topic sensor-data"

echo ""
echo "Recent messages (last 3):"
ssh -i $KEY_FILE ubuntu@$KAFKA_VM "docker exec kafka-broker kafka-console-consumer --bootstrap-server localhost:9092 --topic sensor-data --from-beginning --timeout-ms 3000 | tail -3"

echo ""
echo "📊 4. MONGODB DATA VERIFICATION"
echo "------------------------------"
echo "Database collections:"
ssh -i $KEY_FILE ubuntu@$MONGODB_VM "docker exec mongodb-server mongosh --quiet --eval 'db.adminCommand(\"listCollections\").cursor.firstBatch.forEach(c => print(c.name))'"

echo ""
echo "Document count in processed_data:"
ssh -i $KEY_FILE ubuntu@$MONGODB_VM "docker exec mongodb-server mongosh --quiet --eval 'db.processed_data.countDocuments()'"

echo ""
echo "Recent processed data (last 2):"
ssh -i $KEY_FILE ubuntu@$MONGODB_VM "docker exec mongodb-server mongosh --quiet --eval 'db.processed_data.find().limit(2).forEach(printjson)'"

echo ""
echo "⚙️ 5. PYTHON PROCESSES STATUS"
echo "----------------------------"
echo "Producer process:"
ssh -i $KEY_FILE ubuntu@$PRODUCER_VM "ps aux | grep simple-producer | grep -v grep || echo '  Not running'"

echo ""
echo "Consumer process:"
ssh -i $KEY_FILE ubuntu@$PROCESSOR_VM "ps aux | grep simple-consumer | grep -v grep || echo '  Not running'"

echo ""
echo "🌐 6. WEB INTERFACES"
echo "------------------"
echo "Kafka UI:      http://${KAFKA_VM}:8080"
echo "Mongo Express: http://${MONGODB_VM}:8081"
echo "               (Login: admin / admin123)"

echo ""
echo "📈 7. SYSTEM RESOURCES"
echo "--------------------"
echo "Memory usage on each VM:"
for vm in $KAFKA_VM $MONGODB_VM $PROCESSOR_VM $PRODUCER_VM; do
    echo "VM $vm:"
    ssh -i $KEY_FILE ubuntu@$vm "free -h | grep -E 'total|Mem:|Swap:' | head -3"
    echo ""
done

echo "🔍 8. LOG FILES"
echo "-------------"
echo "Producer logs (last 3 lines):"
ssh -i $KEY_FILE ubuntu@$PRODUCER_VM "tail -3 /opt/kafka-pipeline/producer.log 2>/dev/null || echo '  No logs found'"

echo ""
echo "Consumer logs (last 3 lines):" 
ssh -i $KEY_FILE ubuntu@$PROCESSOR_VM "tail -3 /opt/kafka-pipeline/consumer.log 2>/dev/null || echo '  No logs found'"

echo ""
echo "✅ Pipeline Monitoring Complete!"
echo "================================"