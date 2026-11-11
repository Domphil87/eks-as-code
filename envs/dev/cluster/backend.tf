# State for the dev CLUSTER layer (see ADR 0001).
terraform {
  backend "s3" {
    bucket       = "eks-platform-as-code-tfstate-353695163160-us-east-1"
    key          = "envs/dev/cluster/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
