variable "name" {
  description = "Friendly name for the certificate. Used as the AWS resource Name tag and for log/output identification."
  type        = string
}

variable "common_name" {
  description = "Subject CommonName for the CSR. Usually the wildcard form (e.g. \"*.internal.gauchoracing.com\")."
  type        = string
}

variable "hostnames" {
  description = "All hostnames the cert should be valid for — included both as CSR DNS SANs and on the Cloudflare Origin CA cert. Include the apex and wildcard explicitly (e.g. [\"*.internal.gauchoracing.com\", \"internal.gauchoracing.com\"])."
  type        = list(string)
}

variable "validity_days" {
  description = "Requested certificate validity in days. Cloudflare allows up to 5475 (15 years) for Origin CA."
  type        = number
  default     = 5475
}
