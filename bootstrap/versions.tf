terraform {
  # "~> 1.15" means ">= 1.15.0 and < 2.0.0".
  # It accepts your installed 1.15.9 and later 1.x releases, but blocks a
  # future 2.0 that might contain breaking changes.
  required_version = "~> 1.15"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # "~> 6.70" means ">= 6.70.0 and < 7.0.0". The exact build that
      # `terraform init` picks is recorded in .terraform.lock.hcl.
      version = "~> 6.70"
    }
  }

  # No backend block yet: bootstrap must create the S3 bucket before any
  # configuration can store state in it, so this layer starts with local
  # state. See README.md in this folder for migrating it into S3 afterwards.
}
