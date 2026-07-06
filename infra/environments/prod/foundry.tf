# Foundry (on-prem k3s) cutover resources — the tunnel that connects the
# on-prem cluster to Cloudflare, plus the public DNS records that route
# the four public hostnames to it.
#
# Compute (EKS + ALB + ACM origin cert) still lives in main.tf. Once the
# cutover has soaked and the on-prem cluster owns traffic, delete the
# EKS-side resources from main.tf (module.eks / module.argocd /
# module.origin_cert) and remove kubernetes/apps/ from the repo.
#
# Off-cluster data services (gr-postgres, gr-mqtt, gr-clickhouse) stay in
# AWS — the on-prem cluster reaches them over the public internet via
# their existing Cloudflare A records.
#
# Cutover sequence (short version):
#
#   1. terraform apply this file (fails on step 3 records if EKS
#      external-dns still owns them; delete those records via the CF
#      dashboard first).
#   2. Populate cloudflared-secrets on the on-prem cluster:
#        kubectl -n cloudflared create secret generic cloudflared-secrets \
#          --from-literal=TUNNEL_TOKEN="$(terraform output -raw foundry_tunnel_token)"
#   3. Apply kubernetes/bootstrap/root-foundry.yaml on the on-prem
#      ArgoCD, populate the per-stack Secrets, wait for pods to reach
#      Healthy against gr-postgres / gr-mqtt / gr-clickhouse.
#   4. On the EKS cluster: kubectl -n external-dns scale deploy
#      external-dns --replicas=0 so it stops recreating the ALB records.
#   5. terraform apply again if step 1 stopped short. DNS records
#      now CNAME to the tunnel; traffic starts landing on-prem within
#      the CF TTL.
#   6. Bake. When confident, delete module.eks + module.argocd +
#      module.origin_cert from main.tf and re-apply.

# Account ID for the tunnel resources. The CF API token used by the
# provider is scoped to a single account — return that account's ID.
data "cloudflare_accounts" "current" {}

locals {
  cloudflare_account_id = data.cloudflare_accounts.current.result[0].id
}

# 32-byte tunnel secret, stored in TF state.
resource "random_bytes" "foundry_tunnel_secret" {
  length = 32
}

# Named tunnel. config_src = "cloudflare" means CF hosts the ingress rule
# table (managed by cloudflare_zero_trust_tunnel_cloudflared_config
# below); the on-prem cloudflared pod boots with just a token and pulls
# the ruleset from CF at runtime.
resource "cloudflare_zero_trust_tunnel_cloudflared" "foundry" {
  account_id    = local.cloudflare_account_id
  name          = "gr-foundry"
  tunnel_secret = random_bytes.foundry_tunnel_secret.base64
  config_src    = "cloudflare"
}

# Ingress rules: every public hostname lands on the on-prem cluster's
# Traefik service, and Traefik does host-based routing to the right
# Service in the right namespace. Adding a new public hostname is one
# more block here + one more cloudflare_dns_record below.
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "foundry" {
  account_id = local.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.foundry.id

  config = {
    ingress = [
      {
        hostname = "sentinel-v5.gauchoracing.com"
        service  = "http://traefik.kube-system.svc.cluster.local:80"
      },
      {
        hostname = "mapache.gauchoracing.com"
        service  = "http://traefik.kube-system.svc.cluster.local:80"
      },
      {
        hostname = "vault.gauchoracing.com"
        service  = "http://traefik.kube-system.svc.cluster.local:80"
      },
      {
        hostname = "argocd.gauchoracing.com"
        service  = "http://traefik.kube-system.svc.cluster.local:80"
      },
      # Catch-all — required last entry per CF tunnel ingress schema.
      {
        service = "http_status:404"
      },
    ]
  }
}

# Data source for the tunnel token; consumed by the cloudflared pods on
# the on-prem cluster via TUNNEL_TOKEN. Read with:
#   terraform output -raw foundry_tunnel_token
data "cloudflare_zero_trust_tunnel_cloudflared_token" "foundry" {
  account_id = local.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.foundry.id
}

# Public DNS records. Each is a proxied CNAME to the tunnel's CF-managed
# hostname (<uuid>.cfargotunnel.com); CF proxies + terminates TLS at the
# edge and forwards HTTP through the tunnel.
#
# These were previously created by EKS external-dns. Before first apply,
# either scale that Deployment to 0 or delete the records via the CF
# dashboard so terraform doesn't hit a 409.
locals {
  foundry_hostnames = [
    "sentinel-v5",
    "mapache",
    "vault",
    "argocd",
  ]
}

resource "cloudflare_dns_record" "foundry" {
  for_each = toset(local.foundry_hostnames)

  zone_id = data.cloudflare_zone.gauchoracing.id
  name    = each.value
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.foundry.id}.cfargotunnel.com"
  ttl     = 1 # 1 = auto (required by CF when proxied=true)
  proxied = true
}
