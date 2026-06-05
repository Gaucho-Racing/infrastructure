# ClickHouse on a single EC2 in the EKS VPC. Mirrors the postgres-ec2
# module shape — pods reach it via private IP through the AWS split-horizon
# DNS trick, external admin clients via the EIP + gr-clickhouse hostname.
#
# Columnar OLAP store for telemetry: CAN signals from gr26, Epic Shelter
# ingest output, future analytics queries. Postgres keeps the small
# transactional state (users, vehicles, jobs, sessions).
#
# Backups are NOT included — add a snapshot policy before this holds
# unrecoverable data. ClickHouse data on a dedicated EBS volume so the
# instance can be replaced without losing the database.

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

resource "random_password" "admin" {
  length  = 32
  special = false
}

resource "aws_security_group" "this" {
  name        = var.name
  description = "ClickHouse for ${var.name}"
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

# Ingress on the HTTP + native protocol ports from each allowed SG
# (typically the EKS node SG). 8123 for HTTP clients (query service,
# clickhouse-client --http); 9000 for the native binary protocol
# (clickhouse-client, the Go and Python drivers).
locals {
  ingress_ports = [8123, 9000]
}

resource "aws_security_group_rule" "ingress_sg" {
  for_each = {
    for pair in setproduct(var.allowed_security_group_ids, local.ingress_ports) :
    "${pair[0]}-${pair[1]}" => { sg = pair[0], port = pair[1] }
  }
  type                     = "ingress"
  from_port                = each.value.port
  to_port                  = each.value.port
  protocol                 = "tcp"
  source_security_group_id = each.value.sg
  security_group_id        = aws_security_group.this.id
  description              = "ClickHouse :${each.value.port} from ${each.value.sg}"
}

# Ingress from arbitrary CIDR blocks (admin laptops, the public internet,
# etc.). 32-char random admin password + sha256_hex on the wire is the only
# gate; tighten the CIDR list later when a known set of admin IPs exists.
resource "aws_security_group_rule" "ingress_cidr" {
  for_each          = length(var.admin_cidr_blocks) > 0 ? toset([for p in local.ingress_ports : tostring(p)]) : []
  type              = "ingress"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
  protocol          = "tcp"
  cidr_blocks       = var.admin_cidr_blocks
  security_group_id = aws_security_group.this.id
  description       = "ClickHouse :${each.value} from admin CIDRs"
}

resource "aws_ebs_volume" "data" {
  availability_zone = var.availability_zone
  size              = var.data_volume_size_gb
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "${var.name}-data"
  }

  # Preserve the volume across instance replacements. ClickHouse data
  # is the whole reason this server exists; never destroy by accident.
  lifecycle {
    prevent_destroy = true
  }
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
    clickhouse_version    = var.clickhouse_version
    admin_user            = var.admin_user
    admin_password_sha256 = sha256(random_password.admin.result)
  })

  # Re-rendering user-data shouldn't recreate the instance — the data
  # volume preserves state, and admin credentials are generated once
  # and persist in TF state. AMI bumps similarly ignored.
  lifecycle {
    ignore_changes = [user_data, ami]
  }

  tags = {
    Name = "${var.name}"
    Role = "clickhouse"
  }
}

resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf" # appears as /dev/nvme1n1 inside the instance
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.this.id
}

resource "aws_eip" "this" {
  count    = var.associate_public_ip ? 1 : 0
  domain   = "vpc"
  instance = aws_instance.this.id

  tags = {
    Name = "${var.name}"
  }
}
