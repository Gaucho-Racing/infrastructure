variable "name" {
  description = "Friendly name for the Postgres instance. Used in resource Name tags + SG name."
  type        = string
}

variable "vpc_id" {
  description = "VPC the EC2 lives in. Should be the same VPC as EKS so pods reach it via private IP."
  type        = string
}

variable "subnet_id" {
  description = "Private subnet to launch into. Pick one; this is a single-AZ deployment, no multi-AZ failover."
  type        = string
}

variable "availability_zone" {
  description = "AZ for the instance + EBS data volume. Must match the AZ of the chosen subnet — EBS is AZ-scoped."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type. t4g.medium (4GB RAM, ARM) is a good starting point for Sentinel-scale workloads."
  type        = string
  default     = "t4g.medium"
}

variable "data_volume_size_gb" {
  description = "Size of the EBS data volume in GB. Sized for growth headroom; resize via TF when needed."
  type        = number
  default     = 50
}

variable "db_name" {
  description = "Application database to ensure exists on first boot. Defaults to \"postgres\" which is the always-present default DB — create per-service DBs (sentinel, mapache, ...) separately via SQL once the server is up."
  type        = string
  default     = "postgres"
}

variable "allowed_security_group_ids" {
  description = "Security group IDs allowed to connect on port 5432. Typically the EKS node SG."
  type        = list(string)
  default     = []
}

variable "admin_cidr_blocks" {
  description = "CIDR blocks allowed to connect to 5432 directly. Use specific IPs (your laptop, office) for least exposure, or \"0.0.0.0/0\" to leave password as the only gate."
  type        = list(string)
  default     = []
}

variable "associate_public_ip" {
  description = "If true, the instance gets a public IP via an EIP. Required when allowing inbound connections from outside the VPC."
  type        = bool
  default     = false
}
