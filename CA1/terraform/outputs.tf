# CA1 Terraform Outputs

# Network Information
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = module.networking.public_subnet_id
}

# Instance Information
output "producer_instance_ip" {
  description = "Public IP of the conveyor producer instance"
  value       = module.compute.producer_public_ip
}

output "kafka_instance_ip" {
  description = "Public IP of the Kafka hub instance"
  value       = module.compute.kafka_public_ip
}

output "processor_instance_ip" {
  description = "Public IP of the data processor instance"
  value       = module.compute.processor_public_ip
}

output "influxdb_instance_ip" {
  description = "Public IP of the InfluxDB instance"
  value       = module.compute.influxdb_public_ip
}

output "grafana_instance_ip" {
  description = "Public IP of the Grafana dashboard instance"
  value       = module.compute.grafana_public_ip
}

# Private IPs for internal communication
output "kafka_private_ip" {
  description = "Private IP of the Kafka hub instance"
  value       = module.compute.kafka_private_ip
}

output "influxdb_private_ip" {
  description = "Private IP of the InfluxDB instance"
  value       = module.compute.influxdb_private_ip
}

# Service Endpoints
output "kafka_endpoint" {
  description = "Kafka broker endpoint"
  value       = "${module.compute.kafka_private_ip}:9092"
}

output "influxdb_endpoint" {
  description = "InfluxDB API endpoint"
  value       = "http://${module.compute.influxdb_private_ip}:8086"
}

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = "http://${module.compute.grafana_public_ip}:3000"
}

# SSH Commands
output "ssh_commands" {
  description = "SSH commands to connect to instances"
  value = {
    producer  = "ssh -i ~/.ssh/ca1-key.pem ubuntu@${module.compute.producer_public_ip}"
    kafka     = "ssh -i ~/.ssh/ca1-key.pem ubuntu@${module.compute.kafka_public_ip}"
    processor = "ssh -i ~/.ssh/ca1-key.pem ubuntu@${module.compute.processor_public_ip}"
    influxdb  = "ssh -i ~/.ssh/ca1-key.pem ubuntu@${module.compute.influxdb_public_ip}"
    grafana   = "ssh -i ~/.ssh/ca1-key.pem ubuntu@${module.compute.grafana_public_ip}"
  }
}

# Validation Commands
output "validation_commands" {
  description = "Commands to validate the pipeline"
  value = {
    producer_logs    = "ssh -i ~/.ssh/ca1-key.pem ubuntu@${module.compute.producer_public_ip} 'tail -f producer.log'"
    kafka_topics     = "ssh -i ~/.ssh/ca1-key.pem ubuntu@${module.compute.kafka_public_ip} 'sudo docker exec kafka kafka-topics.sh --bootstrap-server localhost:9092 --list'"
    kafka_consumer   = "ssh -i ~/.ssh/ca1-key.pem ubuntu@${module.compute.kafka_public_ip} 'sudo docker exec kafka kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic conveyor-speed --max-messages 5'"
    processor_logs   = "ssh -i ~/.ssh/ca1-key.pem ubuntu@${module.compute.processor_public_ip} 'tail -f processor.log'"
    influxdb_health  = "curl -s http://${module.compute.influxdb_public_ip}:8086/health"
    influxdb_query   = "curl -X POST -H 'Authorization: Token ${var.influxdb_token}' -H 'Content-type: application/vnd.flux' 'http://${module.compute.influxdb_public_ip}:8086/api/v2/query?org=${var.influxdb_org}' -d 'from(bucket:\"${var.influxdb_bucket}\") |> range(start: -1m) |> limit(n: 5)'"
  }
  sensitive = true
}