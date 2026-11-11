# ADR 0001: Separate Terraform state into network, cluster and platform layers

- **Status:** Accepted
- **Date:** 2026-10-27

## Context

The platform consists of an AWS network (VPC, subnets, NAT), an EKS cluster
(control plane, node groups, IAM, EFS), and platform add-ons installed
*inside* the cluster with Helm (load balancer controller, cert-manager,
Argo CD, and so on).

Putting all of it in one Terraform configuration with one state file causes
problems:

1. **Provider bootstrapping.** The Kubernetes and Helm providers need a
   running cluster's endpoint and credentials. In a single configuration
   they are configured from values that do not exist until the cluster is
   created, which makes the first apply, and any cluster replacement,
   unreliable.
2. **Blast radius.** A mistake in an add-on change could produce a plan that
   touches the VPC or the cluster.
3. **Speed and clarity.** Every plan refreshes hundreds of resources, which
   makes plans slow and hard to review.
4. **Lifecycles differ.** The network changes rarely, the cluster a few
   times a year (upgrades), and add-ons often.

## Decision

Each environment uses three independent root configurations, each with its
own state file in the shared S3 bucket:

| Layer | Folder | State key |
|---|---|---|
| Network | `envs/<env>/network` | `envs/<env>/network/terraform.tfstate` |
| Cluster | `envs/<env>/cluster` | `envs/<env>/cluster/terraform.tfstate` |
| Platform | `envs/<env>/platform` | `envs/<env>/platform/terraform.tfstate` |

Later layers read earlier layers' outputs through
`data "terraform_remote_state"` (read-only). Apply order is network →
cluster → platform. Destroy order is the reverse.

The `bootstrap/` configuration (state bucket, budget) sits outside this
scheme and is applied once.

## Consequences

**Positive**
- The Kubernetes and Helm providers in the platform layer connect to a cluster that already exists.
- Smaller, faster, easier-to-review plans. A broken add-on cannot touch the VPC.
- CI can plan or apply a single layer, and IAM permissions can be scoped per layer.
- Separate state per environment: dev changes cannot affect staging.

**Negative**
- More folders and more `init`/`apply` runs. Order matters.
- Outputs shared between layers become a contract: renaming an output
  can break the next layer.
- `terraform_remote_state` gives a layer read access to the *whole* state
  file of the layer before it, not just its outputs. This is acceptable
  here because one team owns all layers.
- Destroy must follow reverse order, or a layer will fail on
  dependencies it can no longer read.
