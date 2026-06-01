output "vpc_id" {
  description = "ID of the created VPC."
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "Primary CIDR of the VPC."
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets, one per AZ."
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "IDs of the private subnets, one per AZ. EKS nodes and Karpenter-provisioned instances land here."
  value       = module.vpc.private_subnets
}

output "nat_public_ips" {
  description = "Public IPs assigned to the NAT gateway."
  value       = module.vpc.nat_public_ips
}
