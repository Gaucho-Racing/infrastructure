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

output "depot_prod_usw2_bucket" {
  description = "S3 bucket name for Depot production storage in us-west-2."
  value       = aws_s3_bucket.depot_prod_usw2.id
}

output "depot_prod_use1_bucket" {
  description = "S3 bucket name for Depot production storage in us-east-1."
  value       = aws_s3_bucket.depot_prod_use1.id
}

output "depot_prod_access_key_id" {
  description = "Access key ID for the depot-prod IAM user. Configure it through Depot's storage backend UI or API."
  value       = aws_iam_access_key.depot_prod.id
}

output "depot_prod_secret_access_key" {
  description = "Secret access key for the depot-prod IAM user. Configure it through Depot's storage backend UI or API."
  value       = aws_iam_access_key.depot_prod.secret
  sensitive   = true
}

output "minecraft_relay_public_ip" {
  description = "EIP of the Minecraft relay. Point an unproxied play.gauchoracing.com A record at it."
  value       = module.minecraft_relay.public_ip
}

output "minecraft_relay_instance_id" {
  description = "Minecraft relay instance ID, for `aws ssm start-session`."
  value       = module.minecraft_relay.instance_id
}

output "minecraft_relay_frp_token" {
  description = "frp token for the Minecraft relay. Seed into the Vault secret `warden-prod` as frp_token."
  value       = module.minecraft_relay.frp_token
  sensitive   = true
}
