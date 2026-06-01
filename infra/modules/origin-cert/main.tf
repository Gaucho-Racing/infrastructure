# Cloudflare Origin Certificate pipeline:
#
#   1. Generate an RSA private key in-cluster (kept in TF state only)
#   2. Build a CSR with the requested SANs
#   3. Cloudflare's Origin CA signs the CSR (15-year validity by default)
#   4. Import the resulting cert + key into AWS ACM so the ALB can present it
#
# These certs are only trusted by Cloudflare's edge — never by browsers
# directly. The flow expects Cloudflare to be in front (orange-cloud
# proxied DNS), terminating the public-facing TLS and then re-establishing
# TLS to the origin using this cert as the trust anchor.
#
# The private key lives in S3 (terraform state) encrypted at rest. Acceptable
# for now; revisit if we ever need to share it outside terraform.

terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "this" {
  private_key_pem = tls_private_key.this.private_key_pem

  subject {
    common_name = var.common_name
  }

  dns_names = var.hostnames
}

resource "cloudflare_origin_ca_certificate" "this" {
  csr                = tls_cert_request.this.cert_request_pem
  hostnames          = var.hostnames
  request_type       = "origin-rsa"
  requested_validity = var.validity_days
}

resource "aws_acm_certificate" "this" {
  certificate_body = cloudflare_origin_ca_certificate.this.certificate
  private_key      = tls_private_key.this.private_key_pem

  # ACM doesn't let you mutate an imported cert in place; force a new one
  # if the underlying cert content changes (e.g. CSR regeneration).
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = var.name
  }
}
