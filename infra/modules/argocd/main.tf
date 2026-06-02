# ArgoCD installed via Helm. This is the bootstrap install — ArgoCD takes
# over self-management once the root Application (kubernetes/bootstrap/root.yaml)
# is kubectl-apply'd. From that point, even ArgoCD upgrades happen via Git.
#
# The Helm release is intentionally minimal here. App-level config (RBAC,
# SSO, notification rules, projects) gets layered on by ArgoCD itself
# reading from this repo, not by terraform.

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = var.namespace
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version

  values = [
    yamlencode({
      global = {
        # Used by Ingress if/when we enable it. Harmless until then.
        domain = var.domain
        # Pin every ArgoCD component to the on-demand baseline NodePool.
        # GitOps needs to stay up to drive recovery when the spot pool
        # churns; on-demand is more expensive but worth it for the
        # control plane. See kubernetes/manifests/on-demand-nodepool/.
        nodeSelector = {
          "capacity-type" = "on-demand-baseline"
        }
      }
      configs = {
        params = {
          # TLS terminates at the ALB later; the server itself runs HTTP.
          # Saves having to deal with self-signed certs in-cluster.
          "server.insecure" = true
        }
      }
    })
  ]

  # ArgoCD pods need a node — Karpenter sees the pending pods and
  # provisions one. Helm will time out waiting if Karpenter can't
  # schedule (e.g. no NodePool ready). Default timeout (300s) is
  # usually enough; bump if your cluster takes longer to provision.
  timeout = 600
}
