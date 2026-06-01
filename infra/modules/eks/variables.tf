variable "name" {
  description = "EKS cluster name."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes minor version (e.g. \"1.33\"). EKS supports the last few releases; check the AWS docs for the current support window."
  type        = string
  default     = "1.33"
}

variable "vpc_id" {
  description = "ID of the VPC the cluster will live in."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs the cluster + Auto Mode node pools will provision into. Private subnets are the standard choice."
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Whether the EKS API endpoint is reachable from the public internet. Required for kubectl from a laptop without a bastion."
  type        = bool
  default     = true
}

variable "node_pools" {
  description = "Default Auto Mode node pools to enable. Valid values are \"general-purpose\" and \"system\". Custom Karpenter NodePool CRs can be added later without touching this list."
  type        = list(string)
  default     = ["general-purpose", "system"]
}

variable "tags" {
  description = "Tags applied to cluster resources."
  type        = map(string)
  default     = {}
}
