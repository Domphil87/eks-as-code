# Read the CLUSTER layer's outputs (endpoint, CA, EFS ID) from its state
# file in S3. Read-only: this layer can never change the cluster.
data "terraform_remote_state" "cluster" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = "envs/${var.environment}/cluster/terraform.tfstate"
    region = var.aws_region
  }
}
