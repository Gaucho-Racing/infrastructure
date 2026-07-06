# ArgoCD installed via Helm. This is the bootstrap install — ArgoCD takes
# over self-management once the root Application (kubernetes/gr-prod/bootstrap/root.yaml)
# is kubectl-apply'd. From that point, even ArgoCD upgrades happen via Git.
#
# SSO (Sentinel OIDC) and RBAC live in the chart values below so a single
# owner (this Helm release) manages argocd-cm / argocd-rbac-cm — managing
# those ConfigMaps from both Helm and a GitOps Application makes them flap.
#
# Two manual prerequisites before SSO works (neither belongs in Git):
#
#   1. Register the ArgoCD application in Sentinel:
#        - client_id: argocd  (must match var.oidc_client_id)
#        - redirect_uri: https://<var.domain>/auth/callback
#        - link the "Admins" group (and any others you want visible) to the
#          app so they appear in the groups claim; optionally mark a group
#          "required" to gate who can log in at all (Sentinel access gate).
#
#   2. Create the OIDC client secret in-cluster (referenced by oidc.config
#      as $argocd-sentinel-oidc:oidc.clientSecret — kept out of Git/state):
#        kubectl -n argocd create secret generic argocd-sentinel-oidc \
#          --from-literal=oidc.clientSecret='<secret-from-sentinel>'
#        kubectl -n argocd label secret argocd-sentinel-oidc \
#          app.kubernetes.io/part-of=argocd

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
        # control plane. See kubernetes/gr-prod/manifests/on-demand-nodepool/.
        nodeSelector = {
          "capacity-type" = "on-demand-baseline"
        }
        # The on-demand pool is tainted `dedicated=argocd:NoSchedule` to
        # keep other workloads off it. ArgoCD tolerates so its pods
        # actually schedule there.
        tolerations = [
          {
            key      = "dedicated"
            operator = "Equal"
            value    = "argocd"
            effect   = "NoSchedule"
          }
        ]
      }
      configs = {
        params = {
          # TLS terminates at the ALB later; the server itself runs HTTP.
          # Saves having to deal with self-signed certs in-cluster.
          "server.insecure" = true
        }
        cm = {
          # Public URL — used to build the OIDC redirect (…/auth/callback).
          url = "https://${var.domain}"
          # Sentinel OIDC. requestedScopes uses Sentinel's scope names:
          # groups:read (NOT "groups") gates the groups claim, and
          # offline_access requests a refresh token so sessions persist past
          # the ~30m access-token TTL.
          "oidc.config" = yamlencode({
            name                   = "Sentinel"
            issuer                 = var.oidc_issuer
            clientID               = var.oidc_client_id
            clientSecret           = "$argocd-sentinel-oidc:oidc.clientSecret"
            requestedScopes        = ["openid", "profile", "email", "groups:read", "offline_access"]
            requestedIDTokenClaims = { groups = { essential = true } }
          })
        }
        rbac = {
          # Sentinel emits group names in the groups claim, so policies key on
          # the readable name. Everyone who can log in gets read-only; the
          # admin group gets full access.
          "policy.default" = "role:readonly"
          "policy.csv"     = "g, ${var.admin_group}, role:admin"
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
