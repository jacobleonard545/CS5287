# Compute Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "name_prefix" {
  description = "Unique name prefix for all resources"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "ubuntu_ami_id" {
  description = "AMI ID for Ubuntu instances"
  type        = string
}

variable "key_name" {
  description = "Name of the AWS key pair"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet for instances"
  type        = string
}

# Security Group IDs
variable "producer_sg_id" {
  description = "Security group ID for producer instance"
  type        = string
}

variable "kafka_sg_id" {
  description = "Security group ID for Kafka instance"
  type        = string
}

variable "processor_sg_id" {
  description = "Security group ID for processor instance"
  type        = string
}

variable "influxdb_sg_id" {
  description = "Security group ID for InfluxDB instance"
  type        = string
}

variable "grafana_sg_id" {
  description = "Security group ID for Grafana instance"
  type        = string
}

# Configuration Variables
variable "kafka_heap_opts" {
  description = "Kafka JVM heap options"
  type        = string
  default     = "-Xmx150m -Xms75m"
}

variable "kafka_memory_limit" {
  description = "Memory limit for Kafka container (MB)"
  type        = number
  default     = 300
}

variable "influxdb_token" {
  description = "InfluxDB authentication token"
  type        = string
  sensitive   = true
}

variable "influxdb_org" {
  description = "InfluxDB organization name"
  type        = string
}

variable "influxdb_bucket" {
  description = "InfluxDB bucket name"
  type        = string
}

variable "influxdb_username" {
  description = "InfluxDB admin username"
  type        = string
  default     = "admin"
}

variable "influxdb_password" {
  description = "InfluxDB admin password"
  type        = string
  sensitive   = true
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

