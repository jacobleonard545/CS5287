# Compute Module for CA1
# Creates EC2 instances for the IoT pipeline components

# CA1-conveyor-producer Instance
resource "aws_instance" "producer" {
  ami                    = var.ubuntu_ami_id
  instance_type         = "t2.micro"
  key_name              = var.key_name
  subnet_id             = var.subnet_id
  vpc_security_group_ids = [var.producer_sg_id]

  user_data = base64encode(templatefile("${path.module}/user_data/producer_setup.sh", {
    kafka_broker_ip = aws_instance.kafka.private_ip
  }))

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-conveyor-producer"
    Component = "producer"
  })
}

# CA1-kafka-hub Instance
resource "aws_instance" "kafka" {
  ami                    = var.ubuntu_ami_id
  instance_type         = "t2.micro"
  key_name              = var.key_name
  subnet_id             = var.subnet_id
  vpc_security_group_ids = [var.kafka_sg_id]

  user_data = base64encode(templatefile("${path.module}/user_data/kafka_kraft_setup.sh", {
    kafka_heap_opts        = var.kafka_heap_opts
    kafka_memory_limit     = var.kafka_memory_limit
  }))

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-kafka-hub"
    Component = "kafka"
  })
}

# CA1-data-processor Instance
resource "aws_instance" "processor" {
  ami                    = var.ubuntu_ami_id
  instance_type         = "t2.micro"
  key_name              = var.key_name
  subnet_id             = var.subnet_id
  vpc_security_group_ids = [var.processor_sg_id]

  user_data = base64encode(templatefile("${path.module}/user_data/processor_setup.sh", {
    kafka_broker_ip = aws_instance.kafka.private_ip
    influxdb_ip     = aws_instance.influxdb.private_ip
    influxdb_token  = var.influxdb_token
    influxdb_org    = var.influxdb_org
    influxdb_bucket = var.influxdb_bucket
  }))

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-data-processor"
    Component = "processor"
  })
}

# CA1-influx-db Instance
resource "aws_instance" "influxdb" {
  ami                    = var.ubuntu_ami_id
  instance_type         = "t2.micro"
  key_name              = var.key_name
  subnet_id             = var.subnet_id
  vpc_security_group_ids = [var.influxdb_sg_id]

  user_data = base64encode(templatefile("${path.module}/user_data/influxdb_setup.sh", {
    influxdb_username = var.influxdb_username
    influxdb_password = var.influxdb_password
    influxdb_org      = var.influxdb_org
    influxdb_bucket   = var.influxdb_bucket
    influxdb_token    = var.influxdb_token
  }))

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-influx-db"
    Component = "influxdb"
  })
}

# CA1-grafana-dash Instance
resource "aws_instance" "grafana" {
  ami                    = var.ubuntu_ami_id
  instance_type         = "t2.micro"
  key_name              = var.key_name
  subnet_id             = var.subnet_id
  vpc_security_group_ids = [var.grafana_sg_id]

  user_data = base64encode(templatefile("${path.module}/user_data/grafana_setup.sh", {
    influxdb_ip            = aws_instance.influxdb.private_ip
    influxdb_token         = var.influxdb_token
    influxdb_org           = var.influxdb_org
    influxdb_bucket        = var.influxdb_bucket
    grafana_admin_password = var.grafana_admin_password
  }))

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-grafana-dash"
    Component = "grafana"
  })
}