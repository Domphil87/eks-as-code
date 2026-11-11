# Dev cluster settings. No secrets, so this file IS committed.
# Your public IP lives in the git-ignored admin-access.auto.tfvars instead.

aws_region   = "us-east-1"
project      = "eks-platform-as-code"
environment  = "dev"
owner        = "Domphil87"
cost_center  = "portfolio"
state_bucket = "eks-platform-as-code-tfstate-353695163160-us-east-1"

# 1.36: standard support until 2027-08-01. Not 1.37 yet, because Cluster
# Autoscaler (whose version must match the Kubernetes minor) has no 1.37
# release as of 2026-10-30.
kubernetes_version = "1.36"

# AWS-default versions for 1.36 as of 2026-11-06, from:
#   aws eks describe-addon-versions --kubernetes-version 1.36 --addon-name <name>
addon_versions = {
  "vpc-cni"                = "v1.22.4-eksbuild.10"
  "kube-proxy"             = "v1.36.0-eksbuild.60"
  "coredns"                = "v1.14.7-eksbuild.28"
  "eks-pod-identity-agent" = "v1.4.1-eksbuild.3"
}

# Your Terraform/CLI IAM user gets cluster-admin via an EKS access entry.
cluster_admin_principal_arns = [
  "arn:aws:iam::353695163160:user/aws-cli-terraform-DO-NOT-DELETE",
]

# Security-relevant logs only, 7 days, to keep CloudWatch cost low.
enabled_log_types  = ["audit", "authenticator"]
log_retention_days = 7

# Spot: about 70% cheaper than on-demand; AWS may reclaim a node with 2
# minutes' warning and EKS replaces it. All types are 2 vCPU / 8 GiB.
node_capacity_type  = "SPOT"
node_instance_types = ["t3a.large", "t3.large", "m5a.large", "m6i.large", "m5.large"]

# 3 nodes = one per AZ. Max 6 leaves room for the Cluster Autoscaler test.
node_min_size     = 3
node_desired_size = 3
node_max_size     = 6
