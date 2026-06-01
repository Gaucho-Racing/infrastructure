# Postgres on a single EC2 in the EKS VPC. Native install (not Docker)
# for simpler debugging + standard ops. Data lives on a separate EBS
# volume so the instance can be replaced without losing the database.
#
# Backups are NOT included — add an aws_dlm_lifecycle_policy or move
# to snapshot-on-cron before this holds production data.

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

data "aws_vpc" "this" {
  id = var.vpc_id
}

# Random password generated once and stored in state. Read via:
#   terraform output -raw postgres_password
# (which the caller uses to populate the k8s Secret.) Manage rotations
# by tainting this resource later.
resource "random_password" "postgres" {
  length  = 32
  special = false
}

resource "aws_security_group" "this" {
  name        = "${var.name}"
  description = "Postgres for ${var.name}"
  vpc_id      = var.vpc_id

  # Egress for outbound package installs (apt/dnf) during user-data.
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

# Ingress on 5432 from each allowed SG (typically the EKS node SG).
resource "aws_security_group_rule" "ingress_sg" {
  for_each                 = toset(var.allowed_security_group_ids)
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = each.value
  security_group_id        = aws_security_group.this.id
  description              = "Postgres from ${each.value}"
}

resource "aws_ebs_volume" "data" {
  availability_zone = var.availability_zone
  size              = var.data_volume_size_gb
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "${var.name}-data"
  }

  # Preserve the volume across instance replacements. To intentionally
  # destroy the volume (and the database), set this to false and apply,
  # then re-apply with it set back to true after the destroy.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_instance" "this" {
  ami                    = data.aws_ami.al2023_arm64.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.this.id]
  availability_zone      = var.availability_zone

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    postgres_password = random_password.postgres.result
    db_name           = var.db_name
    vpc_cidr          = data.aws_vpc.this.cidr_block
  })

  # Re-rendering user-data shouldn't recreate the instance — the data
  # volume preserves state anyway, and the password is generated once.
  lifecycle {
    ignore_changes = [user_data, ami]
  }

  tags = {
    Name = "${var.name}"
    Role = "postgres"
  }
}

resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf" # appears as /dev/nvme1n1 inside the instance
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.this.id
}
