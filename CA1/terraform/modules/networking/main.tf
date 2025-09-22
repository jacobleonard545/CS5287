# Networking Module for CA1
# Creates VPC, subnets, and networking infrastructure

# VPC
resource "aws_vpc" "ca1_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "ca1_igw" {
  vpc_id = aws_vpc.ca1_vpc.id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-igw"
  })
}

# Public Subnet
resource "aws_subnet" "ca1_public_subnet" {
  vpc_id                  = aws_vpc.ca1_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-public-subnet"
  })
}

# Route Table for Public Subnet
resource "aws_route_table" "ca1_public_rt" {
  vpc_id = aws_vpc.ca1_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ca1_igw.id
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-public-rt"
  })
}

# Route Table Association
resource "aws_route_table_association" "ca1_public_rta" {
  subnet_id      = aws_subnet.ca1_public_subnet.id
  route_table_id = aws_route_table.ca1_public_rt.id
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}