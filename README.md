# infrastructure

Gaucho Racing's AWS infrastructure and Kubernetes deployment configuration.

## Layout

```
infra/         Terraform — VPC, EKS, Karpenter, ALB controller
kubernetes/    GitOps — Helm charts, ArgoCD apps, per-env values
```

The two trees are decoupled. Terraform is applied manually (or via the
plan/apply workflows); Kubernetes manifests are reconciled continuously by
ArgoCD after the cluster is bootstrapped.

## Region

`us-west-2`.

## State backend

S3 with native locking (`use_lockfile = true`, Terraform ≥ 1.10). No
DynamoDB lock table required.
