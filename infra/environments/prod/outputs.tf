# Retrieval requires management-account credentials, which is deliberate:
# these values are seeded into Vault once and consumed from there. Do not
# hand them to team members by pointing them at terraform output or state.
output "mapache_prod_access_key_id" {
  description = "Access key ID for the mapache-prod IAM user. Seed into the Vault secret `mapache` as aws_access_key_id."
  value       = aws_iam_access_key.mapache_prod.id
}

output "mapache_prod_secret_access_key" {
  description = "Secret access key for the mapache-prod IAM user. Seed into the Vault secret `mapache` as aws_secret_access_key."
  value       = aws_iam_access_key.mapache_prod.secret
  sensitive   = true
}
