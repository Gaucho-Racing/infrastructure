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

# Wildcard cert for *.internal.gauchoracing.com — every team-only service
# (argocd, future sentinel admin UIs, etc.) terminates TLS on its ALB
# using this cert. Public-facing TLS terminates at the Cloudflare edge
# using Cloudflare's auto-generated edge cert.
module "origin_cert_internal" {
  source = "../../modules/origin-cert"

  name        = "internal.gauchoracing.com"
  common_name = "*.internal.gauchoracing.com"
  hostnames = [
    "*.internal.gauchoracing.com",
    "internal.gauchoracing.com",
  ]
}
