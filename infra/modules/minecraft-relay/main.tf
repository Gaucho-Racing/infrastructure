# Public entry point for the Minecraft server on gr-foundry. gr-foundry has
# no public IP and the Cloudflare tunnel only carries HTTP, so frps runs
# here on an EIP and the in-cluster frpc dials out to it; player traffic on
# 25565 is relayed back down that connection.
#
# The frp token is generated in TF state and embedded via user-data. Read
# it once with `terraform output -raw minecraft_relay_frp_token` and seed
# it into Vault; the frpc pod consumes it from there.

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
    values = ["al2023-ami-2023.*-kernel-*-arm64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "random_password" "frp_token" {
  length  = 48
  special = false
}

resource "aws_security_group" "this" {
  name        = var.name
  description = "frps relay for ${var.name}"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.name
  }
}

resource "aws_security_group_rule" "minecraft" {
  type              = "ingress"
  from_port         = var.minecraft_port
  to_port           = var.minecraft_port
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.this.id
  description       = "Minecraft players"
}

# Open to the world because gr-foundry's egress IP is not stable. frps
# requires TLS and the token, and only lets clients bind minecraft_port.
resource "aws_security_group_rule" "frp_control" {
  type              = "ingress"
  from_port         = var.frp_bind_port
  to_port           = var.frp_bind_port
  protocol          = "tcp"
  cidr_blocks       = var.frp_client_cidr_blocks
  security_group_id = aws_security_group.this.id
  description       = "frpc control connection from gr-foundry"
}

# SSM Session Manager instead of SSH, so there is no port 22 to expose.
resource "aws_iam_role" "this" {
  name = var.name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  name = var.name
  role = aws_iam_role.this.name
}

resource "aws_instance" "this" {
  ami                    = data.aws_ami.al2023_arm64.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.this.id]
  iam_instance_profile   = aws_iam_instance_profile.this.name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    frp_version    = var.frp_version
    frp_sha256     = var.frp_sha256
    frp_bind_port  = var.frp_bind_port
    frp_token      = random_password.frp_token.result
    minecraft_port = var.minecraft_port
  })

  # frps is stateless, so a config change should rebuild the box rather
  # than store new user_data that only runs on the next stop/start.
  user_data_replace_on_change = true

  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name = var.name
    Role = "frps"
  }
}

resource "aws_eip" "this" {
  domain   = "vpc"
  instance = aws_instance.this.id

  tags = {
    Name = var.name
  }
}
