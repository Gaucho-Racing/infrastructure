# One-off import blocks to reconcile state with reality after a partial
# apply + an out-of-band fix. Remove this file in a follow-up PR once CI
# has run and these are no longer needed.
#
# Background:
# - The EKS cluster_creator access entry oscillated between admin-cli
#   (local apply) and the CI role (CI apply) because the module derives
#   its principal_arn from the current session. CI's apply revoked
#   admin-cli's access. admin-cli was re-added directly via aws CLI to
#   restore kubectl, but it now lives outside state.
# - module.argocd.helm_release.argocd was lost from state during the
#   same failed CI apply but the helm release still exists in-cluster.

import {
  to = module.eks.module.eks.aws_eks_access_entry.this["arn-aws-iam--211125506628-user-admin-cli"]
  id = "gr-prod:arn:aws:iam::211125506628:user/admin-cli"
}

import {
  to = module.eks.module.eks.aws_eks_access_policy_association.this["arn-aws-iam--211125506628-user-admin-cli_admin"]
  id = "gr-prod#arn:aws:iam::211125506628:user/admin-cli#arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
}

import {
  to = module.argocd.helm_release.argocd
  id = "argocd/argocd"
}
