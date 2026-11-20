# ADR 0003: How CI reaches AWS and the cluster

- **Status:** Accepted
- **Date:** 2026-11-19

## Context

Milestone 6 runs Terraform from GitHub Actions. The repository is public.
Two questions:

1. How do workflows get AWS credentials, and which runs may change
   infrastructure?
2. How do they reach the EKS API? The platform layer (Helm, Kubernetes
   providers) needs it, and the public endpoint only accepts the admin IP.

## Decision

**Credentials: GitHub OIDC, two roles, no stored keys** (created in
`bootstrap`, which CI never applies):

| Role | Trusted for | Permissions |
|---|---|---|
| `github-actions-eks-platform-as-code-plan` | Pull requests from this repository and pushes to `main` | `ReadOnlyAccess` + write/delete of state `.tflock` objects |
| `github-actions-eks-platform-as-code-apply` | Jobs running in the protected GitHub environments `dev` / `staging` (required reviewer) | `PowerUserAccess` + IAM only on `eks-platform-as-code-<env>-*`; deny on changing the state bucket |

Fork pull requests get no OIDC token, so they can only run the static
checks. The CI roles are named outside the pattern the apply role may
manage, so CI cannot widen its own rights.

**Cluster API: a CodeBuild-hosted GitHub Actions runner in the VPC**
(Milestone 6b). Jobs that need Kubernetes run on an AWS CodeBuild runner
in the private subnets and use the private endpoint; everything else runs
on GitHub-hosted runners. The public endpoint stays limited to the admin
IP. CodeBuild is billed per build minute, with no idle cost. Because the
repository is public, the runner's webhook accepts only jobs triggered by
the repository owner.

## Consequences

- An approved apply is effectively an administrator for the project's
  resources (it can create IAM roles under the project prefix). The
  protection is the trust policy plus the required reviewer on the
  environment, not the permission set. Tighten with a permissions
  boundary before production.
- Admin IPs stay out of Git: CI reads them from the `ADMIN_CIDRS` secret,
  and the variables are `sensitive`, so public logs and PR comments show
  `(sensitive value)`.
- The runner exists only while the dev network does; platform jobs are
  skipped when dev is torn down.
- A one-time manual step: the CodeConnections connection to GitHub must
  be approved in the AWS console.

## Alternatives considered

- **Add each runner's IP to the endpoint allow-list during the job.** No
  new infrastructure, but every endpoint update takes several minutes
  (twice per run) and fights Terraform's own setting. Rejected.
- **Open the public endpoint to everyone, relying on IAM only.** Simplest,
  but removes a layer of defence that Checkov (CKV_AWS_38) enforces.
  Rejected.
- **A self-hosted runner on an EC2 instance.** Always-on cost and
  patching, and it would run any public pull request. Rejected.
