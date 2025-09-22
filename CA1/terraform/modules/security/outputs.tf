# Security Module Outputs

output "producer_sg_id" {
  description = "ID of the producer security group"
  value       = aws_security_group.producer_sg.id
}

output "kafka_sg_id" {
  description = "ID of the Kafka security group"
  value       = aws_security_group.kafka_sg.id
}

output "processor_sg_id" {
  description = "ID of the processor security group"
  value       = aws_security_group.processor_sg.id
}

output "influxdb_sg_id" {
  description = "ID of the InfluxDB security group"
  value       = aws_security_group.influxdb_sg.id
}

output "grafana_sg_id" {
  description = "ID of the Grafana security group"
  value       = aws_security_group.grafana_sg.id
}