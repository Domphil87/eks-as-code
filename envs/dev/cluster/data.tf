# Read the NETWORK layer's outputs (VPC ID, subnet IDs) from its state
# file in S3. This is read-only: this layer can never change the network.
data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = "envs/${var.environment}/network/terraform.tfstate"
    region = var.aws_region
  }
}
