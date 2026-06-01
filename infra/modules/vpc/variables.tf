variable "name" {
  description = "Name tag applied to the VPC and its associated resources."
  type        = string
}

variable "cidr" {
  description = "Primary IPv4 CIDR block for the VPC."
  type        = string
}

variable "azs" {
  description = "Availability zones to deploy subnets into."
  type        = list(string)
}

variable "public_subnets" {
  description = "Public subnet CIDR blocks, one per AZ."
  type        = list(string)
}

variable "private_subnets" {
  description = "Private subnet CIDR blocks, one per AZ."
  type        = list(string)
}

variable "cluster_name" {
  description = "EKS cluster name. Used to tag private subnets for Karpenter discovery."
  type        = string
}

variable "tags" {
  description = "Tags applied to all VPC resources."
  type        = map(string)
  default     = {}
}
