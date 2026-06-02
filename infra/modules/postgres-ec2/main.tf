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

# Random password generated once and stored in state. Read via:
#   terraform output -raw postgres_password
# (which the caller uses to populate the k8s Secret.) Manage rotations
# by tainting this resource later.
resource "random_password" "postgres" {
  length  = 32
  special = false
}

resource "aws_security_group" "this" {
  name        = var.name
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

# Ingress on 5432 from arbitrary CIDR blocks (admin laptops, the public
# internet, etc.). Only the strong scram-sha-256 password protects this
# path — IP allowlist is the better defense in depth, but the caller
# chose how wide to open it.
resource "aws_security_group_rule" "ingress_cidr" {
  count             = length(var.admin_cidr_blocks) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = var.admin_cidr_blocks
  security_group_id = aws_security_group.this.id
  description       = "Postgres from admin CIDRs"
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
    postgres_password = random_password.postgres.result
    db_name           = var.db_name
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

# Stable public IP. Stop/start of the underlying instance would otherwise
# rotate the auto-assigned public IP and break DNS.
resource "aws_eip" "this" {
  count    = var.associate_public_ip ? 1 : 0
  domain   = "vpc"
  instance = aws_instance.this.id

  tags = {
    Name = "${var.name}"
  }
}
