# Networking Module Outputs

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.ca1_vpc.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.ca1_vpc.cidr_block
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.ca1_public_subnet.id
}

output "public_subnet_cidr" {
  description = "CIDR block of the public subnet"
  value       = aws_subnet.ca1_public_subnet.cidr_block
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.ca1_igw.id
}