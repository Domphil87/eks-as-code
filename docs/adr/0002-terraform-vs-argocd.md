# ADR 0002: What Terraform owns and what Argo CD owns

- **Status:** Accepted
- **Date:** 2026-11-10

## Context

From Milestone 5 the cluster has two deployment tools: Terraform (with
the Helm provider) and Argo CD. If both manage the same object they
overwrite each other, and it becomes unclear where a change should be
made.

## Decision

**Terraform owns everything that needs AWS resources or must exist
before Argo CD can run:**

- AWS infrastructure: VPC, EKS, node groups, IAM roles and Pod Identity
  associations, Secrets Manager secrets, ACM certificates, Route 53 CAA,
  CloudWatch log groups.
- Platform add-ons (`modules/addons`): CSI drivers, Load Balancer
  Controller, ExternalDNS, cert-manager, External Secrets Operator,
  monitoring, logging, Cluster Autoscaler.
- Argo CD itself and the single root Application (`modules/gitops`).

**Argo CD owns everything below `gitops/` in Git:**

- Team namespaces and their guardrails (RBAC, quotas, limits, Pod
  Security labels) and Argo CD projects (Milestone 5c).
- Applications (Milestone 5d onwards).

The root Application ("App of Apps") is the only hand-over point:
Terraform creates it, and it points Argo CD at `gitops/apps`.

## Consequences

- Platform changes go through `terraform plan`/`apply` (and CI from
  Milestone 6); application and team changes go through a Git commit,
  and Argo CD applies them automatically (`prune` and `selfHeal` on).
- A rollback of an application is a `git revert`.
- Anything Argo CD needs from AWS (an IAM role for an app, a secret) is
  still created by Terraform first, then referenced from Git.
- Teardown order matters: delete the root Application first (its
  finalizer removes the apps and their load balancers), then destroy the
  platform layer.

## Alternatives considered

- **Argo CD also installs the add-ons.** Fewer Terraform resources, but
  the add-ons need IAM roles and AWS IDs from Terraform state, which then
  have to be copied into Git. Rejected for this project.
- **Terraform deploys the applications too.** One tool, but no
  continuous reconciliation, no self-healing and no Git-based rollback,
  which the brief asks for. Rejected.
