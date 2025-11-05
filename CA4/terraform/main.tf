terraform {
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

# Get latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create VPC
resource "aws_vpc" "ca4_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "ca4-vpc"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "ca4_igw" {
  vpc_id = aws_vpc.ca4_vpc.id

  tags = {
    Name = "ca4-igw"
  }
}

# Create Public Subnet
resource "aws_subnet" "ca4_public_subnet" {
  vpc_id                  = aws_vpc.ca4_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "ca4-public-subnet"
  }
}

# Create Route Table
resource "aws_route_table" "ca4_public_rt" {
  vpc_id = aws_vpc.ca4_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ca4_igw.id
  }

  tags = {
    Name = "ca4-public-rt"
  }
}

# Associate Route Table
resource "aws_route_table_association" "ca4_public_assoc" {
  subnet_id      = aws_subnet.ca4_public_subnet.id
  route_table_id = aws_route_table.ca4_public_rt.id
}

# Security Group
resource "aws_security_group" "ca4_cloud_sg" {
  name        = "ca4-cloud-sg"
  description = "Security group for CA4 cloud instance"
  vpc_id      = aws_vpc.ca4_vpc.id

  # SSH from anywhere (for simplicity - restrict in production)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ca4-cloud-sg"
  }
}

# SSH Key Pair
resource "aws_key_pair" "ca4_key" {
  key_name   = "ca4-ssh-key"
  public_key = file(var.ssh_public_key_path)
}

# EC2 Instance (t3.small) - Cloud Components
resource "aws_instance" "ca4_cloud" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.ca4_public_subnet.id
  vpc_security_group_ids = [aws_security_group.ca4_cloud_sg.id]
  key_name               = aws_key_pair.ca4_key.key_name

  root_block_device {
    volume_size = 10
    volume_type = "gp3"
  }

  user_data = <<-EOF
              #!/bin/bash
              set -e

              # Update system
              apt-get update
              apt-get install -y curl wget git docker.io

              # Enable Docker
              systemctl enable docker
              systemctl start docker

              # Install Docker Compose (lightweight alternative to k3s for t2.micro)
              curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
              chmod +x /usr/local/bin/docker-compose

              # Create docker group and add ubuntu user
              usermod -aG docker ubuntu

              # Create directory for configs
              mkdir -p /home/ubuntu/ca4-cloud
              chown -R ubuntu:ubuntu /home/ubuntu/ca4-cloud

              # Signal completion
              touch /home/ubuntu/cloud-init-complete
              EOF

  tags = {
    Name = "ca4-cloud-instance"
    Type = "cloud"
  }
}

# Outputs
output "cloud_instance_id" {
  value = aws_instance.ca4_cloud.id
}

output "cloud_instance_public_ip" {
  value = aws_instance.ca4_cloud.public_ip
}

output "cloud_instance_private_ip" {
  value = aws_instance.ca4_cloud.private_ip
}

output "ssh_command" {
  value = "ssh -i ${var.ssh_private_key_path} ubuntu@${aws_instance.ca4_cloud.public_ip}"
}
