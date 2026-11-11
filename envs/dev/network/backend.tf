# State for the dev NETWORK layer. Each layer and environment has its own
# key, so this state file can never overwrite another (see ADR 0001).
terraform {
  backend "s3" {
    bucket       = "eks-platform-as-code-tfstate-353695163160-us-east-1"
    key          = "envs/dev/network/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
