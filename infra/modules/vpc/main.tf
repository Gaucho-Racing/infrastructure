# VPC layout: 3 AZs in us-west-2, public + private subnet per AZ, single
# NAT gateway. The subnet tags are what EKS, the AWS Load Balancer
# Controller, and Karpenter rely on for discovery:
#
#   kubernetes.io/role/elb            — public subnets where ALBs land
#   kubernetes.io/role/internal-elb   — private subnets for internal LBs
#   karpenter.sh/discovery            — private subnets Karpenter provisions into

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = var.name
  cidr = var.cidr

  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "karpenter.sh/discovery"          = var.cluster_name
  }

  tags = var.tags
}
