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

  cluster_admin_principals = [
    "arn:aws:iam::211125506628:user/admin-cli",
  ]
}

module "argocd" {
  source = "../../modules/argocd"

  # No custom values for now. Domain placeholder until DNS lands.
  domain = "argocd.gauchoracing.com"

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

  name              = "sentinel"
  vpc_id            = module.vpc.vpc_id
  subnet_id         = module.vpc.private_subnet_ids[0]
  availability_zone = "us-west-2a"

  instance_type       = "t4g.medium"
  data_volume_size_gb = 50

  allowed_security_group_ids = [
    module.eks.node_security_group_id,
  ]
}
