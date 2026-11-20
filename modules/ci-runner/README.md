# Module: ci-runner

A CodeBuild-hosted GitHub Actions runner in the private subnets, so CI
jobs can reach the EKS private API endpoint while the public endpoint
stays limited to the admin IP ([ADR 0003](../../docs/adr/0003-ci-access.md)).

A workflow job opts in with:

```yaml
runs-on: codebuild-<name>-${{ github.run_id }}-${{ github.run_attempt }}
```

CodeBuild starts one build per queued job; the build registers as a
one-off runner, runs that job and ends. Billed per build minute
(`BUILD_GENERAL1_MEDIUM`, about $0.01/minute); nothing runs while idle.

| Resource | Purpose |
|---|---|
| `aws_codebuild_project` | The runner: Amazon Linux standard 5.0 image (includes the AWS CLI for `aws eks get-token`), private subnets, not privileged |
| `aws_codebuild_webhook` | Takes only `WORKFLOW_JOB_QUEUED` events from the listed workflows **and** the listed GitHub account IDs |
| `aws_security_group` | Outbound only: 443 anywhere, DNS to the VPC resolver |
| `aws_iam_role` | Build service role: logs, VPC network interfaces, the GitHub connection. Jobs get their AWS rights from the GitHub OIDC roles, not from this role |
| `aws_cloudwatch_log_group` | `/aws/codebuild/<name>`, short retention |

## Why the actor filter matters

The repository is public. Without `allowed_actor_ids`, a pull request
from anyone could queue a job on this runner and run code inside the
VPC. Runs triggered by any other account are ignored by the webhook (the
job then waits until GitHub cancels it).

## Inputs

| Name | Description |
|---|---|
| `name` | Project name, also the `runs-on` prefix; must match `<project>-<env>-*` (the CI apply role's IAM scope) |
| `vpc_id`, `vpc_cidr`, `subnet_ids` | Where builds run (private subnets, NAT for outbound) |
| `github_repository_url`, `github_connection_arn` | Repository and the CodeConnections connection (bootstrap; must be `AVAILABLE`) |
| `allowed_actor_ids` | Numeric GitHub account IDs allowed to use the runner |
| `allowed_workflow_names` | Workflow `name:` values allowed to use the runner |
| `compute_type`, `image`, `build_timeout_minutes`, `concurrent_build_limit`, `log_retention_days`, `tags` | Optional tuning |

Outputs: `project_name`, `security_group_id` (the cluster layer allows it
to the API on 443), `role_arn`.

Prerequisite: the account's CodeBuild source credential for GitHub
(`aws_codebuild_source_credential` in bootstrap).
