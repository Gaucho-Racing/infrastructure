variable "namespace" {
  description = "Kubernetes namespace ArgoCD installs into. Created if missing."
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "Version of the argo-cd Helm chart. Pin to a major to allow patch updates without surprises."
  type        = string
  default     = "8.5.10"
}

variable "domain" {
  description = "Domain ArgoCD will be served from (used by the chart for ingress + redirect URLs). Set even if Ingress isn't enabled yet — values are inert until the Ingress resource exists."
  type        = string
  default     = "argocd.local"
}

variable "oidc_issuer" {
  description = "OIDC issuer for SSO. Must byte-match Sentinel's ISSUER and the iss claim in its tokens."
  type        = string
  default     = "https://sentinel-v5.gauchoracing.com"
}

variable "oidc_client_id" {
  description = "client_id of the application registered in Sentinel for ArgoCD. Sentinel auto-generates this (a random 12-char string) at registration; it can't be named — copy the value from the registered app. Required."
  type        = string
}

variable "admin_group" {
  description = "Sentinel group name (matched against the OIDC groups claim) granted ArgoCD role:admin. Everyone else who can log in gets role:readonly."
  type        = string
  default     = "Admins"
}
