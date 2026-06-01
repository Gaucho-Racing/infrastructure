# Terraform 1.10+ native S3 state locking. Each env writes its state to a
# distinct key under the shared bucket so they don't collide.
terraform {
  required_version = ">= 1.10"

  backend "s3" {
    bucket       = "gaucho-racing-tfstate"
    key          = "environments/prod/terraform.tfstate"
    region       = "us-west-2"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# Cloudflare provider picks up credentials from the CLOUDFLARE_API_TOKEN
# environment variable. Token needs Zone:Read, DNS:Edit, and
# SSL and Certificates:Edit on the gauchoracing.com zone.
provider "cloudflare" {}

provider "aws" {
  region = "us-west-2"

  default_tags {
    tags = {
      Environment = "prod"
      ManagedBy   = "terraform"
      Repo        = "gaucho-racing/infrastructure"
    }
  }
}

# Helm provider authenticates to EKS via `aws eks get-token`, which uses
# whatever AWS credentials are already in the environment (the OIDC role
# in CI; the local user otherwise). Both paths have cluster admin —
# CI via enable_cluster_creator_admin_permissions on the EKS module,
# local via the cluster_admin_principals access entry.
provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", "us-west-2"]
    }
  }
}
