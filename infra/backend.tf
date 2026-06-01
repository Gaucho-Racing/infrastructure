# Terraform 1.10+ native S3 state locking. The `use_lockfile = true` flag
# uses an S3 object with If-None-Match for compare-and-swap; no DynamoDB
# table is needed. Each environment overrides `key` via -backend-config so
# state files don't collide.
#
# Bootstrap order:
#   1. Manually create the S3 bucket (versioning + SSE enabled) — chicken/
#      egg with Terraform, do it via the AWS console or a one-off script.
#   2. `terraform init -backend-config="key=environments/dev/terraform.tfstate"`
#
# TODO: replace <bucket-name> once the state bucket exists.
terraform {
  required_version = ">= 1.10"

  backend "s3" {
    bucket       = "<bucket-name>"
    key          = "placeholder.tfstate"
    region       = "us-west-2"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}
