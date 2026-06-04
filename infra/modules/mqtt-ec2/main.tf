# NanoMQ on a single EC2 in the EKS VPC. Mirrors the postgres-ec2
# module shape — the on-car TCM publishes telemetry here, mapache gr26
# subscribes from inside the cluster.
#
# Anonymous auth is disabled; a random password is generated in TF state
# and embedded in the nanomq config via user-data. Read with:
#   terraform output -raw mqtt_password
# then populate the k8s Secret (mapache-secrets / MQTT_PASSWORD) and the
# on-car TCM config with the same value.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

data "aws_ami" "al2023_arm64" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-arm64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "random_password" "mqtt" {
  length  = 32
  special = false
}

resource "aws_security_group" "this" {
  name        = var.name
  description = "NanoMQ for ${var.name}"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}"
  }
}

resource "aws_security_group_rule" "ingress_sg" {
  for_each                 = toset(var.allowed_security_group_ids)
  type                     = "ingress"
  from_port                = 1883
  to_port                  = 1883
  protocol                 = "tcp"
  source_security_group_id = each.value
  security_group_id        = aws_security_group.this.id
  description              = "MQTT from ${each.value}"
}

# Ingress on 1883 from arbitrary CIDR blocks. The on-car TCM publishes
# from cellular networks with no stable IP, so 0.0.0.0/0 + the strong
# random password is the operating model. Tighten the CIDR list once
# uplink is on a known carrier range.
resource "aws_security_group_rule" "ingress_cidr" {
  count             = length(var.admin_cidr_blocks) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = 1883
  to_port           = 1883
  protocol          = "tcp"
  cidr_blocks       = var.admin_cidr_blocks
  security_group_id = aws_security_group.this.id
  description       = "MQTT from admin CIDRs"
}

resource "aws_instance" "this" {
  ami                         = data.aws_ami.al2023_arm64.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.this.id]
  availability_zone           = var.availability_zone
  associate_public_ip_address = var.associate_public_ip

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    nanomq_version = var.nanomq_version
    mqtt_user      = var.mqtt_user
    mqtt_password  = random_password.mqtt.result
  })

  # Don't recycle the instance on user-data churn. nanomq carries no
  # persistent state we care about across replacements, so AMI bumps
  # are also benign — `terraform taint` to intentionally replace.
  lifecycle {
    ignore_changes = [user_data, ami]
  }

  tags = {
    Name = "${var.name}"
    Role = "nanomq"
  }
}

resource "aws_eip" "this" {
  count    = var.associate_public_ip ? 1 : 0
  domain   = "vpc"
  instance = aws_instance.this.id

  tags = {
    Name = "${var.name}"
  }
}
