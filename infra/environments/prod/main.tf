# Prod environment composition. Modules are referenced from ../../modules/;
# see those directories for the input/output contracts. Backend + provider
# config lives in backend.tf so terraform-apply CI can `terraform init`
# against this directory directly.

locals {
  cluster_name = "gr-prod"
}

module "vpc" {
  source = "../../modules/vpc"

  name = "${local.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets  = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
  private_subnets = ["10.0.48.0/20", "10.0.64.0/20", "10.0.80.0/20"]

  cluster_name = local.cluster_name
}

module "eks" {
  source = "../../modules/eks"

  name               = local.cluster_name
  kubernetes_version = "1.35"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  # Both the local IAM user (admin-cli) and the CI OIDC role need cluster
  # admin. Listed explicitly so the set is stable regardless of who runs
  # terraform — the module's auto-cluster-creator flag is disabled to
  # avoid the entry flipping between appliers.
  cluster_admin_principals = [
    "arn:aws:iam::211125506628:user/admin-cli",
    "arn:aws:iam::211125506628:role/github-actions-terraform",
  ]
}

module "argocd" {
  source = "../../modules/argocd"

  domain = "argocd.gauchoracing.com"

  # Sentinel-generated client_id for the registered ArgoCD application.
  oidc_client_id = "XwwQhdCWZ9Cn"

  depends_on = [module.eks]
}

# Wildcard cert for *.gauchoracing.com — every service (argocd, sentinel,
# whatever else lands later) terminates TLS on its ALB using this cert.
# Public-facing TLS terminates at the Cloudflare edge using Cloudflare's
# auto-generated edge cert.
#
# First-level wildcard (not *.internal.*) because Cloudflare free-plan
# Universal SSL only covers single-depth subdomains. Deeper nesting would
# need Advanced Certificate Manager.
module "origin_cert" {
  source = "../../modules/origin-cert"

  name        = "gauchoracing.com"
  common_name = "*.gauchoracing.com"
  hostnames = [
    "*.gauchoracing.com",
    "gauchoracing.com",
  ]
}

# Postgres on EC2. Lives in the EKS VPC so pods reach it via private IP;
# SG-locked to traffic originating from the EKS node SG so nothing outside
# the cluster can connect. ARM/Graviton (t4g.medium) for cost.
#
# Generated password is in TF state — read with:
#   terraform output -raw postgres_password
# then create a k8s Secret manually:
#   kubectl -n sentinel create secret generic sentinel-secrets \
#     --from-literal=POSTGRES_PASSWORD="$(terraform output -raw postgres_password)" \
#     --from-literal=DISCORD_TOKEN=...
module "postgres" {
  source = "../../modules/postgres-ec2"

  name              = "gr-postgres"
  vpc_id            = module.vpc.vpc_id
  subnet_id         = module.vpc.public_subnet_ids[0]
  availability_zone = "us-west-2a"

  instance_type       = "t4g.medium"
  data_volume_size_gb = 50

  # Public IP + open to the internet on 5432. The 32-char random password
  # + scram-sha-256 is the only gate; tighten the CIDR list later if/when
  # a known set of admin IPs makes sense.
  associate_public_ip = true
  admin_cidr_blocks   = ["0.0.0.0/0"]

  allowed_security_group_ids = [
    module.eks.node_security_group_id,
  ]
}

# Cloudflare DNS record for the Postgres EIP. Gray-cloud (proxied = false)
# because Cloudflare's free plan only proxies HTTP/HTTPS, not TCP. The real
# IP is exposed in DNS as a result — SG + Postgres auth are the protection.
data "cloudflare_zone" "gauchoracing" {
  filter = {
    name = "gauchoracing.com"
  }
}

resource "cloudflare_dns_record" "gr_postgres" {
  zone_id = data.cloudflare_zone.gauchoracing.id
  name    = "gr-postgres"
  type    = "A"
  content = module.postgres.public_ip
  ttl     = 300
  proxied = false
}

# NanoMQ on EC2 — same shape as gr-postgres. mapache/gr26 subscribes
# from inside the cluster; the on-car TCM publishes from a cellular IP,
# so this needs a public EIP + open ingress. The 32-char random password
# is the only gate.
#
# Read the password and populate the k8s Secret + on-car TCM with:
#   kubectl -n mapache create secret generic mapache-secrets \
#     --from-literal=MQTT_PASSWORD="$(terraform output -raw mqtt_password)" \
#     ...
module "mqtt" {
  source = "../../modules/mqtt-ec2"

  name              = "gr-mqtt"
  vpc_id            = module.vpc.vpc_id
  subnet_id         = module.vpc.public_subnet_ids[0]
  availability_zone = "us-west-2a"

  associate_public_ip = true
  admin_cidr_blocks   = ["0.0.0.0/0"]

  allowed_security_group_ids = [
    module.eks.node_security_group_id,
  ]
}

resource "cloudflare_dns_record" "gr_mqtt" {
  zone_id = data.cloudflare_zone.gauchoracing.id
  name    = "gr-mqtt"
  type    = "A"
  content = module.mqtt.public_ip
  ttl     = 300
  proxied = false
}

# Per-hostname SSL/TLS override. The zone defaults to "Flexible" (CF
# talks HTTP to origin), but our ALB-backed Ingresses run HTTPS-only
# with the imported Origin CA cert — Flexible there causes a redirect
# loop and Cloudflare returns 522. Listed per-hostname instead of
# flipping the whole zone to Full strict, since other origins on
# gauchoracing.com (legacy WordPress, etc.) still need Flexible.
#
# Cloudflare allows one entrypoint ruleset per (zone, phase). The
# argocd rule was originally created via the dashboard, which Cloudflare
# stores as an http_config_settings ruleset under the hood. We import
# that existing ruleset and add the sentinel-v5 rule alongside it.
resource "cloudflare_ruleset" "ssl_overrides" {
  zone_id = data.cloudflare_zone.gauchoracing.id
  name    = "Per-hostname SSL overrides"
  kind    = "zone"
  phase   = "http_config_settings"

  rules = [
    {
      description = "argocd-strict-mode"
      expression  = "(http.host eq \"argocd.gauchoracing.com\")"
      action      = "set_config"
      enabled     = true
      action_parameters = {
        ssl = "strict"
      }
    },
    {
      description = "sentinel-v5-strict-mode"
      expression  = "(http.host eq \"sentinel-v5.gauchoracing.com\")"
      action      = "set_config"
      enabled     = true
      action_parameters = {
        ssl = "strict"
      }
    },
    {
      description = "mapache-strict-mode"
      expression  = "(http.host eq \"mapache.gauchoracing.com\")"
      action      = "set_config"
      enabled     = true
      action_parameters = {
        ssl = "strict"
      }
    },
  ]
}

# One-off — picks up the existing argocd-only ruleset created via the
# CF dashboard. Remove this import block in a follow-up PR once apply
# has run and the resource is fully terraform-owned.
import {
  to = cloudflare_ruleset.ssl_overrides
  id = "zones/${data.cloudflare_zone.gauchoracing.id}/358ead87ac2f47668378942a2a23b7d7"
}
