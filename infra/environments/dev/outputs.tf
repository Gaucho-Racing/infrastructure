output "depot_dev_access_key_id" {
  description = "Access key ID for the depot-dev IAM user. Pairs with depot_dev_secret_access_key in Depot's .env (S3_ACCESS_KEY_ID)."
  value       = aws_iam_access_key.depot_dev.id
}

output "depot_dev_secret_access_key" {
  description = "Secret access key for the depot-dev IAM user. Read with `terraform output -raw depot_dev_secret_access_key` → Depot .env (S3_SECRET_ACCESS_KEY)."
  value       = aws_iam_access_key.depot_dev.secret
  sensitive   = true
}

output "depot_dev_use1_bucket" {
  description = "S3 bucket name for Depot development storage in us-east-1."
  value       = aws_s3_bucket.depot_dev_use1.id
}
