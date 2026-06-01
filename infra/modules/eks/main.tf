# EKS cluster with Auto Mode enabled. AWS manages the data-plane bits
# (Karpenter, VPC CNI, kube-proxy, CoreDNS, EBS CSI, ALB controller) and
# we get a working cluster with no addon wrangling.
#
# Auto Mode nodes run Bottlerocket and don't expose SSH — debugging is via
# `kubectl debug node/...` or SSM. The node_pools we enable here are the
# AWS-provided defaults; custom NodePool CRs can be added later via the
# kubernetes/ tree once ArgoCD is bootstrapped.

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.name
  kubernetes_version = var.kubernetes_version

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  # Public API endpoint so kubectl-from-laptop works without a bastion.
  # Private-only is more secure but adds a setup hop we don't need yet.
  endpoint_public_access = var.endpoint_public_access

  # Adds the IAM principal running terraform (the OIDC role in CI, the
  # user locally) as a cluster admin via an access entry. Without this
  # only the IAM role that created the cluster has admin.
  enable_cluster_creator_admin_permissions = true

  # Auto Mode. node_pools picks the AWS-managed default Karpenter pools
  # to enable; "general-purpose" is the workhorse, "system" is small
  # instances for system pods. Custom NodePool CRs can be added later
  # without changing this list.
  compute_config = {
    enabled    = true
    node_pools = var.node_pools
  }

  # Cluster admin access entries for human operators. The IAM principal
  # that runs `terraform apply` is already granted admin via
  # enable_cluster_creator_admin_permissions above — these entries are
  # for everyone else who needs kubectl access (e.g. a user who runs
  # apply via CI but also needs to debug from their laptop).
  access_entries = {
    for principal_arn in var.cluster_admin_principals :
    replace(principal_arn, "/[^a-zA-Z0-9-]/", "-") => {
      principal_arn = principal_arn
      policy_associations = {
        admin = {
          # EKS access policies use the arn:aws:eks::aws:cluster-access-policy/
          # scheme — NOT the standard IAM policy ARN format. These are managed
          # by EKS, not IAM.
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  tags = var.tags
}
