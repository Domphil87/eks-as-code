terraform {
  required_version = "~> 1.15"

  required_providers {
    aws        = { source = "hashicorp/aws", version = ">= 6.70, < 7.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = ">= 3.4, < 4.0" }
    helm       = { source = "hashicorp/helm", version = ">= 3.3, < 4.0" }
  }
}
