# The dev network layer is just a call to the shared module. Staging calls
# the same module with different values in its own terraform.tfvars.
module "network" {
  source = "../../../modules/network"

  name                 = "${var.project}-${var.environment}"
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  single_nat_gateway   = var.single_nat_gateway
}

# GitHub Actions runner in the private subnets (Milestone 6b, ADR 0003).
# Lives with the network because it needs the VPC; it costs nothing while
# idle and goes away with the network at teardown.
module "ci_runner" {
  source = "../../../modules/ci-runner"
  count  = var.ci_runner_enabled ? 1 : 0

  name       = "${var.project}-${var.environment}-ci-runner"
  vpc_id     = module.network.vpc_id
  vpc_cidr   = module.network.vpc_cidr
  subnet_ids = module.network.private_subnet_ids

  github_repository_url  = var.ci_github_repository_url
  github_connection_arn  = var.ci_github_connection_arn
  allowed_actor_ids      = var.ci_allowed_actor_ids
  allowed_workflow_names = var.ci_workflow_names
}
