locals {
  cluster = data.terraform_remote_state.cluster.outputs

  # Also passed to modules for resources that controllers create (ALBs),
  # which provider default tags do not reach.
  default_tags = {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = "terraform"
    Layer       = "platform"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.default_tags
  }
}

# Talks to the Kubernetes API of the cluster layer's cluster.
# No kubeconfig file is used: a short-lived token is fetched with the
# AWS CLI on every run, using the same IAM identity as Terraform.
provider "kubernetes" {
  host                   = local.cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(local.cluster.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", local.cluster.cluster_name, "--region", var.aws_region]
  }
}

# Installs Helm charts into the same cluster, with the same login method.
provider "helm" {
  kubernetes = {
    host                   = local.cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(local.cluster.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", local.cluster.cluster_name, "--region", var.aws_region]
    }
  }
}
