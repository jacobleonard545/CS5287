# Security Module for CA1
# Creates security groups for each component of the IoT pipeline

# Producer Security Group
resource "aws_security_group" "producer_sg" {
  name        = "${var.project_name}-producer-sg"
  description = "Security group for conveyor producer instance"
  vpc_id      = var.vpc_id

  # SSH access from your IP
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-producer-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Kafka Security Group
resource "aws_security_group" "kafka_sg" {
  name        = "${var.project_name}-kafka-sg"
  description = "Security group for Kafka hub instance"
  vpc_id      = var.vpc_id

  # SSH access from your IP
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # Kafka broker port (from producer and processor)
  ingress {
    description     = "Kafka Broker"
    from_port       = 9092
    to_port         = 9092
    protocol        = "tcp"
    security_groups = [aws_security_group.producer_sg.id, aws_security_group.processor_sg.id]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-kafka-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Processor Security Group
resource "aws_security_group" "processor_sg" {
  name        = "${var.project_name}-processor-sg"
  description = "Security group for data processor instance"
  vpc_id      = var.vpc_id

  # SSH access from your IP
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-processor-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# InfluxDB Security Group
resource "aws_security_group" "influxdb_sg" {
  name        = "${var.project_name}-influxdb-sg"
  description = "Security group for InfluxDB instance"
  vpc_id      = var.vpc_id

  # SSH access from your IP
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # InfluxDB API port (from processor and grafana)
  ingress {
    description     = "InfluxDB API"
    from_port       = 8086
    to_port         = 8086
    protocol        = "tcp"
    security_groups = [aws_security_group.processor_sg.id, aws_security_group.grafana_sg.id]
  }

  # InfluxDB API access from your IP for testing
  ingress {
    description = "InfluxDB API External"
    from_port   = 8086
    to_port     = 8086
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-influxdb-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Grafana Security Group
resource "aws_security_group" "grafana_sg" {
  name        = "${var.project_name}-grafana-sg"
  description = "Security group for Grafana dashboard instance"
  vpc_id      = var.vpc_id

  # SSH access from your IP
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # Grafana web interface
  ingress {
    description = "Grafana Web"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-grafana-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}