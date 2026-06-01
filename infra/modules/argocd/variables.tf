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
