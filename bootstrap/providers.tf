provider "aws" {
  region = var.aws_region

  # Applied automatically to every taggable resource this provider creates,
  # so no resource can be forgotten when it comes to the tagging standard.
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      Owner       = var.owner
      CostCenter  = var.cost_center
      ManagedBy   = "terraform"
      Layer       = "bootstrap"
    }
  }
}
