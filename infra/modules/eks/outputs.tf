output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "API server endpoint URL."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded CA cert for the API server. Needed for kubectl / Helm providers."
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_security_group_id" {
  description = "Security group attached to the EKS control plane."
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group applied to Auto Mode nodes. Useful when allowlisting node->RDS or node->external traffic."
  value       = module.eks.node_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA. Required when wiring service accounts that assume AWS roles (e.g. external-dns, cert-manager, app-side AWS access)."
  value       = module.eks.oidc_provider_arn
}
