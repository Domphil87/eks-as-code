terraform {
  required_version = "~> 1.15"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Modules state the MINIMUM they need. The root configuration that
      # calls the module pins the exact version through its lock file.
      version = ">= 6.70, < 7.0"
    }
  }
}
