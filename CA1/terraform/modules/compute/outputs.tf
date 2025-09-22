# Compute Module Outputs

# Public IP Addresses
output "producer_public_ip" {
  description = "Public IP of the producer instance"
  value       = aws_instance.producer.public_ip
}

output "kafka_public_ip" {
  description = "Public IP of the Kafka instance"
  value       = aws_instance.kafka.public_ip
}

output "processor_public_ip" {
  description = "Public IP of the processor instance"
  value       = aws_instance.processor.public_ip
}

output "influxdb_public_ip" {
  description = "Public IP of the InfluxDB instance"
  value       = aws_instance.influxdb.public_ip
}

output "grafana_public_ip" {
  description = "Public IP of the Grafana instance"
  value       = aws_instance.grafana.public_ip
}

# Private IP Addresses
output "producer_private_ip" {
  description = "Private IP of the producer instance"
  value       = aws_instance.producer.private_ip
}

output "kafka_private_ip" {
  description = "Private IP of the Kafka instance"
  value       = aws_instance.kafka.private_ip
}

output "processor_private_ip" {
  description = "Private IP of the processor instance"
  value       = aws_instance.processor.private_ip
}

output "influxdb_private_ip" {
  description = "Private IP of the InfluxDB instance"
  value       = aws_instance.influxdb.private_ip
}

output "grafana_private_ip" {
  description = "Private IP of the Grafana instance"
  value       = aws_instance.grafana.private_ip
}

# Instance IDs
output "producer_instance_id" {
  description = "Instance ID of the producer"
  value       = aws_instance.producer.id
}

output "kafka_instance_id" {
  description = "Instance ID of the Kafka hub"
  value       = aws_instance.kafka.id
}

output "processor_instance_id" {
  description = "Instance ID of the processor"
  value       = aws_instance.processor.id
}

output "influxdb_instance_id" {
  description = "Instance ID of the InfluxDB"
  value       = aws_instance.influxdb.id
}

output "grafana_instance_id" {
  description = "Instance ID of the Grafana dashboard"
  value       = aws_instance.grafana.id
}