# CLAUDE.md

Gaucho Racing infrastructure monorepo: Terraform (`infra/`) + GitOps
Kubernetes (`kubernetes/`).

## Hard rules

- **Never run `terraform plan` / `apply` / `destroy` locally.** All Terraform
  goes through Atlantis via pull requests. `terraform validate` and
  `terraform init -backend=false` are fine for checking work.
- Never commit secrets. Secrets live in Vault (vault.gauchoracing.com) and
  reach clusters via `VaultSecretSync` resources.
- Never edit AWS resources imperatively (CLI/console) when a Terraform root
  manages them.

## Terraform workflow

1. Branch, edit, open a PR. Atlantis autoplans any project whose files
   changed (config: `atlantis.yaml` at repo root) and comments the plan.
2. Prod plans wait for PR approval before running; dev plans run
   immediately on push.
3. After approval, comment `atlantis apply` on the PR. Applies happen
   pre-merge; merge after a successful apply.
4. Stale lock from an abandoned PR: comment `atlantis unlock` on that PR.

Environment roots and where their resources live:

- `infra/environments/dev` → Development account 104050870528, via
  `assume_role` on `OrganizationAccountAccessRole`. Sandbox + dev services.
- `infra/environments/prod` → management account 211125506628 directly
  (legacy: EC2 data services, Cloudflare DNS/tunnel, org-level IAM).
- State: `gaucho-racing-tfstate` bucket (management account), one key per
  root, S3 native locking. The `.terraform.lock.hcl` per root is committed.
- State is reachable only from management-account credentials, which team
  members do not get — member credentials live in the dev account, and no
  cross-account bucket policy exists. This is what enforces Atlantis-only:
  local terraform cannot init the backend. Never distribute secrets by
  telling members to read terraform outputs/state; hand them off via Vault.

Shared modules live in `infra/modules/`; environments compose them.

## Kubernetes workflow (gr-foundry)

On-prem k3s cluster, reconciled by its own ArgoCD from
`kubernetes/gr-foundry/apps/` (app-of-apps: `bootstrap/root.yaml`, applied
once manually). To add a service:

1. `manifests/<name>/` — kustomize dir: `namespace.yaml`, workload,
   `service.yaml`, `ingress.yaml` (ingressClassName `traefik`, host under
   `gauchoracing.com`, annotation
   `external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"`),
   `kustomization.yaml` (pin image tags here), and a `vaultsecretsync.yaml`
   if it needs secrets.
2. `apps/<name>.yaml` — ArgoCD Application pointing at that dir (copy an
   existing one; automated sync + prune + selfHeal).
3. Public DNS is written automatically by external-dns; traffic arrives
   through the Cloudflare tunnel → Traefik.

`VaultSecretSync` targets a k8s Secret name, maps fields as
`ENV_VAR: <vault-secret>.<field>`, and rolls listed workloads on change.
Access is denied by default: each sync needs a Kubernetes access rule in the
Vault UI (cluster / namespace / service account / secret selector) — a
`403: kubernetes secret selector is not allowed` sync error means the rule
is missing. This rule must be created manually in the Vault UI; flag it in
the PR description.

## Conventions

- `main` is fully protected with no bypass (not even admins): every PR
  needs an approving review, `infra/` changes need a Code Owner approval
  (`.github/CODEOWNERS`), squash-and-merge is the only merge method, and
  history is linear. Never attempt to push to `main` directly.
- Conventional commits with scope (`feat(dev): …`, `fix(foundry): …`).
  Commit messages become squash-commit titles, so make them PR-worthy.
- Branches: `<github-username>/<feature-name>`.
- PR bodies: short bullet list of changes; call out any required manual
  steps (Vault secrets, access rules).
- The Cloudflare API token lives in the Vault secret `cloudflare`
  (`cloudflare.cloudflare_api_token`) — reference it, never copy it.
