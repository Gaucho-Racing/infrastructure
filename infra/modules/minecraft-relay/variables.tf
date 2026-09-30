variable "name" {
  description = "Name for the relay instance, security group and IAM role."
  type        = string
}

variable "vpc_id" {
  description = "VPC to launch into."
  type        = string
}

variable "subnet_id" {
  description = "Public subnet to launch into. The instance is reached through its EIP."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type. frps only copies bytes, so the smallest ARM instance is enough."
  type        = string
  default     = "t4g.nano"
}

variable "frp_version" {
  description = "Pinned frp release. Must match the frpc image tag in kubernetes/gr-foundry/manifests/warden."
  type        = string
  default     = "0.71.0"
}

variable "frp_sha256" {
  description = "SHA-256 of frp_<frp_version>_linux_arm64.tar.gz from the release's frp_sha256_checksums.txt."
  type        = string
  default     = "f33c293c275d8fc68c654b6fba8f10b2551d6463d09a9fc9cffb7227eae82266"
}

variable "frp_bind_port" {
  description = "Port frpc connects to for its control connection."
  type        = number
  default     = 7000
}

variable "frp_client_cidr_blocks" {
  description = "CIDRs allowed to reach frp_bind_port. Narrow to gr-foundry's egress IP if it ever becomes static."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "minecraft_port" {
  description = "Public port players connect to, and the only port frpc is allowed to bind."
  type        = number
  default     = 25565
}
