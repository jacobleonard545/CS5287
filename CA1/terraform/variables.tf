# CA1 Terraform Variables

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "CA1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "deployment_id" {
  description = "Unique deployment identifier to avoid resource conflicts"
  type        = string
  default     = ""
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]*$", var.deployment_id))
    error_message = "Deployment ID must contain only alphanumeric characters and hyphens."
  }
}

variable "public_key_path" {
  description = "Path to the public key file for EC2 instances"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "my_ip" {
  description = "Your IP address for SSH access (CIDR format)"
  type        = string
  # User must provide this value
}

# Instance Configuration
variable "instance_type" {
  description = "EC2 instance type for all instances"
  type        = string
  default     = "t2.micro"
}

# Kafka Configuration
variable "kafka_memory_limit" {
  description = "Memory limit for Kafka container (MB)"
  type        = number
  default     = 300
}

variable "kafka_heap_opts" {
  description = "Kafka JVM heap options for t2.micro optimization"
  type        = string
  default     = "-Xmx150m -Xms75m"
}

# InfluxDB Configuration
variable "influxdb_token" {
  description = "InfluxDB authentication token"
  type        = string
  default     = "ca1-influxdb-token-12345"
  sensitive   = true
}

variable "influxdb_org" {
  description = "InfluxDB organization name"
  type        = string
  default     = "CA1"
}

variable "influxdb_bucket" {
  description = "InfluxDB bucket name for conveyor data"
  type        = string
  default     = "conveyor_data"
}

variable "influxdb_username" {
  description = "InfluxDB admin username"
  type        = string
  default     = "admin"
}

variable "influxdb_password" {
  description = "InfluxDB admin password"
  type        = string
  default     = "ConveyorPass123!"
  sensitive   = true
}

# Grafana Configuration
variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  default     = "admin"
  sensitive   = true
}