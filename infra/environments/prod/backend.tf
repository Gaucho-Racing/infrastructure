# Prod environment root — resources land in the Gaucho Racing Production
# member account (174765207334) via assume-role; state stays in the shared
# tfstate bucket in the management account under its own key.
#
# Legacy management-account infra (EC2 data services, Cloudflare) is no
# longer terraform-managed — its final state is archived at
# s3://gaucho-racing-tfstate/archive/legacy-mgmt-prod.tfstate (holds the
# generated DB passwords) and the config lives in git history.
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

  assume_role {
    role_arn = "arn:aws:iam::174765207334:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = {
      Environment = "prod"
      ManagedBy   = "terraform"
      Repo        = "gaucho-racing/infrastructure"
    }
  }
}
