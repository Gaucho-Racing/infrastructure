# Dev environment root — resources land in the Gaucho Racing Development
# member account (104050870528) via assume-role; state stays in the shared
# tfstate bucket in the management account under its own key.
terraform {
  required_version = ">= 1.10"

  backend "s3" {
    bucket       = "gaucho-racing-tfstate"
    key          = "environments/dev/terraform.tfstate"
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

  assume_role {
    role_arn = "arn:aws:iam::104050870528:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = {
      Environment = "dev"
      ManagedBy   = "terraform"
      Repo        = "gaucho-racing/infrastructure"
    }
  }
}
