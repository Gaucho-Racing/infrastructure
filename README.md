# infrastructure

Gaucho Racing's AWS infrastructure and Kubernetes deployment configuration.

## Layout

```
infra/         Terraform — AWS accounts, S3, EC2 data services, Cloudflare
  environments/dev    → Gaucho Racing Development account (104050870528)
  environments/prod   → management account (211125506628, legacy infra)
  modules/            shared module definitions
kubernetes/    GitOps — ArgoCD apps + kustomize manifests
  gr-foundry/         on-prem k3s cluster (sentinel, vault, jiffy, atlantis, …)
```

The two trees are decoupled. Terraform changes go through Atlantis on pull
requests; Kubernetes manifests are reconciled continuously by ArgoCD.

## AWS accounts

| Account | ID | Purpose |
|---|---|---|
| gauchoracing | 211125506628 | Org management + legacy prod infra (`environments/prod`) |
| Gaucho Racing Development | 104050870528 | Member sandbox + dev services (`environments/dev`) |
| Gaucho Racing Production | 174765207334 | Future prod home (empty) |

## Terraform workflow — Atlantis only

All Terraform planning and applying happens through
[Atlantis](https://atlantis.gauchoracing.com) on pull requests. **Never run
`terraform plan` or `terraform apply` locally** — local applies race
Atlantis's locks and bypass review.

1. Open a PR touching `infra/` — Atlantis autoplans affected projects and
   comments the diff (prod plans additionally wait for PR approval).
2. Get the PR approved.
3. Comment `atlantis apply` — Atlantis applies pre-merge and reports back.
4. Merge.

If a PR is abandoned with an unapplied plan, comment `atlantis unlock` on it
to release the project lock.

## Kubernetes workflow

ArgoCD on the foundry cluster watches `kubernetes/gr-foundry/apps/` (see
`bootstrap/root.yaml`). Each app is an ArgoCD Application pointing at a
kustomize dir in `manifests/`. Secrets are never committed — they live in
[Vault](https://vault.gauchoracing.com) and sync into namespaces via
`VaultSecretSync` resources, gated by per-namespace access rules configured
in the Vault UI.

## Region

`us-west-2`.

## State backend

S3 (`gaucho-racing-tfstate`, management account) with native locking
(`use_lockfile = true`, Terraform ≥ 1.10). One key per environment root.
Only management-account credentials (Atlantis) can reach the backend —
member credentials live in the dev account and cannot init it locally.
