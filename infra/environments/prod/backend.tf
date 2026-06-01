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
  }
}

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
