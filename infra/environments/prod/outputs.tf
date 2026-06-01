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
