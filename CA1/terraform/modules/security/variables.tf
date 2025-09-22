# Security Module Variables

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

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "my_ip" {
  description = "Your IP address for SSH access (CIDR format)"
  type        = string
}