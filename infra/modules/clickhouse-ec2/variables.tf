variable "name" {
  description = "Friendly name for the ClickHouse instance. Used in resource Name tags + SG name."
  type        = string
}

variable "vpc_id" {
  description = "VPC the EC2 lives in. Should be the same VPC as EKS so pods reach it via private IP."
  type        = string
}

variable "subnet_id" {
  description = "Subnet to launch into. Pick a public subnet if associate_public_ip = true."
  type        = string
}

variable "availability_zone" {
  description = "AZ for the instance + EBS data volume. Must match the AZ of the chosen subnet — EBS is AZ-scoped."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type. ClickHouse benefits significantly from RAM (mark cache, query memory) and dedicated CPU. r8g.xlarge (Graviton4, 4 vCPU, 32 GiB) is the prod default; r-series RAM-optimized, dedicated cores (no t-series credit accounting). Drop to t4g.xlarge if cost matters more than steady-state perf."
  type        = string
  default     = "r8g.xlarge"
}

variable "data_volume_size_gb" {
  description = "Size of the EBS data volume in GB. ClickHouse compresses CAN telemetry ~10:1 vs row stores, so 200 GB lasts a long time. Resize via TF when needed; gp3 supports online grow."
  type        = number
  default     = 200
}

variable "clickhouse_version" {
  description = "Pinned clickhouse/clickhouse-server image tag. Defaults to the Alpine variant — smaller image, musl libc; the regular Ubuntu-based tag drops the `-alpine` suffix. Bump deliberately; major versions occasionally change defaults around merge tree storage."
  type        = string
  default     = "26.3-alpine"
}

variable "admin_user" {
  description = "Admin user created in users.d on first boot. Has access_management = 1 so it can grant further users from SQL."
  type        = string
  default     = "admin"
}

variable "allowed_security_group_ids" {
  description = "Security group IDs allowed to connect on 8123 + 9000. Typically the EKS node SG."
  type        = list(string)
  default     = []
}

variable "admin_cidr_blocks" {
  description = "CIDR blocks allowed to connect to 8123 + 9000 directly. Use specific IPs (your laptop, office) for least exposure, or \"0.0.0.0/0\" to leave the admin password as the only gate."
  type        = list(string)
  default     = []
}

variable "associate_public_ip" {
  description = "If true, the instance gets a public IP via an EIP. Required when allowing inbound connections from outside the VPC."
  type        = bool
  default     = false
}
