# Added after the first apply: bootstrap's own state now lives in the bucket
# it created. Before final teardown, delete this file and run
# `terraform init -migrate-state` to move the state back to local first.
# See README.md in this folder.
terraform {
  backend "s3" {
    bucket       = "eks-platform-as-code-tfstate-353695163160-us-east-1"
    key          = "bootstrap/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
