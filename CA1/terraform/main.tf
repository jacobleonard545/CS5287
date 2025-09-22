# CA1 Main Terraform Configuration
# IoT Data Pipeline: Producer -> Kafka -> Processor -> InfluxDB -> Grafana

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data source for Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu*amd64*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Create a key pair for SSH access
resource "aws_key_pair" "ca1_key" {
  key_name   = "${local.name_prefix}-key"
  public_key = file(var.public_key_path)

  tags = local.common_tags
}

# Networking Module
module "networking" {
  source = "./modules/networking"

  project_name = var.project_name
  environment  = var.environment
  name_prefix  = local.name_prefix
  common_tags  = local.common_tags
}

# Security Module
module "security" {
  source = "./modules/security"

  project_name = var.project_name
  environment  = var.environment
  name_prefix  = local.name_prefix
  common_tags  = local.common_tags
  vpc_id       = module.networking.vpc_id
  my_ip        = var.my_ip
}

# Compute Module
module "compute" {
  source = "./modules/compute"

  project_name       = var.project_name
  environment        = var.environment
  name_prefix        = local.name_prefix
  common_tags        = local.common_tags
  ubuntu_ami_id      = data.aws_ami.ubuntu.id
  key_name          = aws_key_pair.ca1_key.key_name
  subnet_id         = module.networking.public_subnet_id

  # Security Groups
  producer_sg_id    = module.security.producer_sg_id
  kafka_sg_id      = module.security.kafka_sg_id
  processor_sg_id  = module.security.processor_sg_id
  influxdb_sg_id   = module.security.influxdb_sg_id
  grafana_sg_id    = module.security.grafana_sg_id

  # Configuration
  kafka_heap_opts       = var.kafka_heap_opts
  kafka_memory_limit    = var.kafka_memory_limit
  influxdb_token       = var.influxdb_token
  influxdb_org         = var.influxdb_org
  influxdb_bucket      = var.influxdb_bucket
  influxdb_username    = var.influxdb_username
  influxdb_password    = var.influxdb_password
  grafana_admin_password = var.grafana_admin_password
}

# Dashboard Configuration - runs after all infrastructure is deployed
resource "null_resource" "configure_dashboard" {
  # This resource depends on all compute instances being ready
  depends_on = [
    module.compute.producer_instance_id,
    module.compute.kafka_instance_id,
    module.compute.processor_instance_id,
    module.compute.influxdb_instance_id,
    module.compute.grafana_instance_id
  ]

  # Only run if the configure_dashboard.sh script exists
  provisioner "local-exec" {
    command = "bash -c 'sleep 60 && if [ -f \"../configure_dashboard.sh\" ]; then cd .. && chmod +x configure_dashboard.sh && ./configure_dashboard.sh; else echo \"Dashboard configuration script not found - run ./configure_dashboard.sh manually\"; fi'"

    # Set working directory to terraform folder
    working_dir = path.module

    # Continue on error to not fail deployment
    on_failure = continue
  }

  # Trigger re-run if any instance IPs change
  triggers = {
    grafana_ip = module.compute.grafana_public_ip
    influxdb_ip = module.compute.influxdb_private_ip
  }
}