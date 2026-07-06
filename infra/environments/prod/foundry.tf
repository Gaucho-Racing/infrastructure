# Foundry (on-prem k3s) cutover resources — the shared Cloudflare Tunnel
# that connects the on-prem cluster to Cloudflare. Public DNS records for
# individual hostnames are managed by external-dns on the foundry cluster
# (see kubernetes/foundry/apps/external-dns.yaml), not here.
#
# Design: the tunnel has a single catch-all ingress rule that forwards
# ALL traffic to the Traefik service. Traefik does Host-based routing
# in-cluster to the right namespace. Adding a new public hostname is
# just an Ingress resource in that service's manifest set — external-dns
# writes the CNAME automatically, no terraform edit needed. Same shape
# works for a second cluster (gr-other-cluster with its own tunnel + own
# external-dns using txtOwnerId=gr-other-cluster).
#
# Compute (EKS + ALB + ACM origin cert) still lives in main.tf. Once
# every hostname is migrated off EKS and the on-prem stack has soaked,
# delete module.eks / module.argocd / module.origin_cert from main.tf
# and remove kubernetes/prod/apps/ from the repo.
#
# Off-cluster data services (gr-postgres, gr-mqtt, gr-clickhouse) stay
# in AWS — the on-prem cluster reaches them over the public internet via
# their existing Cloudflare A records.
#
# Cutover sequence for the first slice (sentinel):
#
#   1. terraform apply this file. Creates the tunnel; no DNS records
#      yet, so no conflict with EKS external-dns.
#   2. Populate cloudflared-secrets + external-dns-config on foundry:
#        kubectl -n cloudflared create secret generic cloudflared-secrets \
#          --from-literal=TUNNEL_TOKEN="$(terraform output -raw foundry_tunnel_token)"
#        kubectl -n external-dns create configmap foundry-tunnel-target \
#          --from-literal=target="$(terraform output -raw foundry_tunnel_id).cfargotunnel.com"
#        kubectl -n external-dns create secret generic cloudflare-api-token \
#          --from-literal=api-token="$CLOUDFLARE_API_TOKEN"
#   3. Apply kubernetes/foundry/bootstrap/root.yaml on the foundry
#      ArgoCD, wait for cloudflared / external-dns / argocd-server-ingress
#      Applications to reach Healthy.
#   4. Cutover for one hostname:
#      a. Scale EKS external-dns to 0 so it stops recreating its records
#         (kubectl --context <eks> -n external-dns scale deploy
#         external-dns --replicas=0).
#      b. Delete the hostname's CNAME + `ext-cname-<hostname>` TXT
#         records via CF dashboard.
#      c. Foundry external-dns notices the matching Ingress with no
#         record, writes CNAME → <tunnel-id>.cfargotunnel.com within
#         its --interval (1m default).
#      d. Traffic starts landing on foundry within CF TTL.
#   5. Bake. Add each remaining hostname (sentinel-v5 / mapache / vault)
#      in a follow-up PR — copy prod/manifests/<svc>/ into
#      foundry/manifests/<svc>/ with two file changes (ingress.yaml →
#      Traefik + external-dns annotation, postgres.yaml → public
#      hostname). No terraform edit needed.

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

# Catch-all tunnel config. Every request that arrives via a DNS record
# CNAMEd to <tunnel-id>.cfargotunnel.com goes to the foundry Traefik
# service regardless of Host header; Traefik does the Host-based routing
# to the right in-cluster Service.
#
# Adding a hostname to the tunnel is NOT done here — it's implicit: any
# DNS record (written by external-dns for a matching Ingress) that
# points at this tunnel gets served.
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "foundry" {
  account_id = local.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.foundry.id

  config = {
    ingress = [
      {
        service = "http://traefik.kube-system.svc.cluster.local:80"
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
