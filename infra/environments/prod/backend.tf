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
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
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
