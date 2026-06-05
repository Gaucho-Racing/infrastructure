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

# Separate credential for the on-car TCM so a compromised car can't
# masquerade as the cluster-side gr26 (and vice-versa). NanoMQ has no
# per-topic ACLs configured, so this is blast-radius limiting only —
# revoke either user by dropping its line from nanomq_pwd.conf.
resource "random_password" "mqtt_tcm26" {
  length  = 32
  special = false
}

# Credential for mapache services (the in-cluster Go services beyond gr26
# — e.g. query, foreman, future publishers). Distinct from gr26's own
# user so the service-fleet credential can rotate independently of the
# CAN-ingest pipeline.
resource "random_password" "mqtt_mapache" {
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
    nanomq_version        = var.nanomq_version
    mqtt_user             = var.mqtt_user
    mqtt_password         = random_password.mqtt.result
    mqtt_user_tcm26       = var.mqtt_user_tcm26
    mqtt_password_tcm26   = random_password.mqtt_tcm26.result
    mqtt_user_mapache     = var.mqtt_user_mapache
    mqtt_password_mapache = random_password.mqtt_mapache.result
  })

  # Force instance replacement when user_data changes. Without this, the
  # AWS provider's default is to call ModifyInstanceAttribute, which
  # *stores* the new user_data but doesn't re-execute it — the file lands
  # only on the next stop+start. We learned this the hard way: a normal
  # apply that added a third nanomq user updated state in place but left
  # the running broker with the old /etc/nanomq_pwd.conf.
  user_data_replace_on_change = true

  # user_data is intentionally NOT in ignore_changes: nanomq carries no
  # persistent state, so legitimate config edits (new user, ACL change)
  # should flow through a normal `terraform apply` and trigger the ~90s
  # broker downtime willingly. Keeping `ami` ignored so unrelated AL2023
  # AMI churn doesn't silently roll the instance.
  lifecycle {
    ignore_changes = [ami]
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
