output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "acm_certificate_arn" {
  description = "ACM ARN for the *.gauchoracing.com origin cert. Used in Ingress annotations (or picked up automatically by the ALB controller via SAN match)."
  value       = module.origin_cert.acm_certificate_arn
}

output "postgres_private_ip" {
  description = "Private IP of the Postgres EC2. Pods connect to this on 5432."
  value       = module.postgres.private_ip
}

output "postgres_public_ip" {
  description = "Public IP of the Postgres EC2 (EIP). External clients connect to this on 5432, or use gr-postgres.gauchoracing.com."
  value       = module.postgres.public_ip
}

output "postgres_password" {
  description = "Generated postgres user password. Read with `terraform output -raw postgres_password`."
  value       = module.postgres.postgres_password
  sensitive   = true
}
