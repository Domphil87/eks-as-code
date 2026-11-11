# Project plan: EKS Platform as Code

Each milestone is small, reviewed, planned and verified before the next one
starts. **Deployed** means it exists in AWS; **Code** means it only exists in
this repository.

| # | Milestone | Code | Deployed | Adds AWS cost? |
|---|---|---|---|---|
| 1 | Repo skeleton, S3 state bucket, budget alert | ✅ | ✅ 2026-10-27 | Cents/month |
| 2 | Network layer (dev): VPC, 3 public + 3 private subnets, IGW, 1 NAT, S3 endpoint | ✅ | ✅ 2026-10-30 | Yes (NAT + IPv4 about $36/month) |
| 3 | Cluster layer (dev): EKS 1.36, Spot managed node group, IAM, Pod Identity agent, EFS | ✅ | ✅ 2026-10-30 | Yes (about $0.20/hour) |
| 4a | Platform: EBS/EFS CSI and StorageClasses, metrics-server | ✅ | ✅ 2026-10-30 | Only volumes you create |
| 4b | Platform: AWS Load Balancer Controller, ExternalDNS, cert-manager | ✅ | ✅ 2026-10-31 | None until an ALB is created (about $0.03/hour each) |
| 4c | Platform: External Secrets Operator and Secrets Manager | ✅ | ✅ 2026-11-09 (acceptance #8 ✅) | $0.40/secret/month (prorated) |
| 4d | Platform: kube-prometheus-stack, Fluent Bit to CloudWatch | ✅ | ✅ 2026-11-09 (acceptance #9, #10 ✅) | CloudWatch ingestion (cents/session), gp3 10 GiB |
| 4e | Platform: Cluster Autoscaler | ✅ | ✅ 2026-11-09 (acceptance #12 ✅) | Extra nodes while scaling |
| 5a | Publish the code to GitHub (`Domphil87/eks-as-code`, public) | ✅ | ✅ pushed 2026-11-10 | None |
| 5b | GitOps: Argo CD (chart 10.11.6 / v3.5.6), ALB at `argocd.dev.domphil.org` (admin IP only), root App of Apps | ✅ | ✅ 2026-11-10 (HTTPS, IP limit, self-heal verified; ExternalDNS zone fix) | ALB about $0.025/hour |
| 5c | GitOps: team namespaces, RBAC, quotas, Pod Security, Argo CD projects | ⬜ | ⬜ | None |
| 5d | GitOps: sample app (HTTPS, HPA, EFS), rollback by `git revert` | ⬜ | ⬜ | Shares the 5b ALB |
| 6 | CI/CD: OIDC plan/apply roles, fmt/validate/TFLint/Checkov/plan, approvals | ⬜ | ⬜ | None |
| 7 | Staging from the same modules | ⬜ | ⬜ | Yes (temporary) |
| 8 | Run the 16 acceptance tests and record the evidence | ⬜ | ⬜ | Yes (temporary) |
| 9 | Ordered teardown and leftover-resource checks | ⬜ | ⬜ | Reduces cost |

Docs (README, ADRs) are updated in every milestone.

**2026-10-31:** dev (milestones 2–4b) destroyed after verification, in the
order platform (29) → cluster (23) → network (26). Post-teardown sweep found
no instances, volumes, ENIs, NAT gateways, Elastic IPs, load balancers or
DNS records left; apex `domphil.org` records unchanged. Bootstrap (state
bucket, budget) kept. Rebuild network → cluster → platform before 4c.

**2026-11-09:** dev rebuilt from code (26 + 23 + 29 resources) with only
resource IDs changing; add-on pins refreshed to AWS defaults (kube-proxy
eksbuild.60, coredns eksbuild.28, EFS CSI v3.5.4). All checks and drift
clean.

## Decisions so far

| Topic | Decision |
|---|---|
| Region | `us-east-1` |
| Terraform | 1.16.7 locally (Chocolatey-pinned), constraint `~> 1.15`; AWS provider 6.70.0 (lock file) |
| Tags | Project=`eks-platform-as-code`, Owner=`Domphil87`, CostCenter=`portfolio`, Environment per env |
| State | One S3 bucket `eks-platform-as-code-tfstate-353695163160-us-east-1` (bootstrap's own state migrated into it on 2026-10-27), SSE-S3, versioned, `use_lockfile = true`, separate key per env/layer ([ADR 0001](adr/0001-layered-terraform-state.md)) |
| Budget | $5/month project budget (alerting only), plus the existing account-wide `billing-budget` |
| CIDRs | dev `10.10.0.0/16`, staging `10.20.0.0/16`, reserved prod `10.30.0.0/16`, DR `10.40.0.0/16` |
| AZs (dev) | `us-east-1a/b/c` = use1-az1/az2/az4; avoid `us-east-1e` (use1-az3, no EKS support) |
| Kubernetes | 1.36 (not 1.37: no Cluster Autoscaler 1.37 release yet); `upgrade_policy = STANDARD` |
| Cluster access | Auth mode `API` (access entries), no creator-admin bootstrap; public endpoint limited to admin IP /32 (git-ignored tfvars) |
| Nodes (dev) | Managed node group, Spot, 2 vCPU / 8 GiB types, 3–6 nodes, AL2023, IMDSv2 hop limit 1 |
| Workload identity | EKS Pod Identity (no IRSA OIDC provider); trust limited to this account and cluster ARN |
| Add-on delivery | EKS managed add-ons where AWS offers them (CSI drivers, metrics-server); Helm via Terraform for the rest (from 4b) |
| Storage | `gp3` default (encrypted, WaitForFirstConsumer); `efs` with per-PVC access points; legacy `gp2` left untouched |
| Network module | Own module with plain resources (not the community VPC module); `for_each` keyed by AZ; private route table per AZ |
| GitHub OIDC | Reuse the account's existing OIDC provider (read-only `data` source); new roles scoped to `Domphil87/eks-as-code` |
| Domain | Existing zone `domphil.org` (not managed here). Dev owns `*.dev.domphil.org`, staging will own `*.staging.domphil.org` |
| TLS | ALB uses an ACM wildcard per environment; cert-manager uses Let's Encrypt (DNS-01, Route 53). CAA added at the subdomain only |
| Chart versions | LBC 3.6.2, ExternalDNS 1.23.0, cert-manager v1.21.3 (re-checked 2026-11-06), ESO 2.14.0 |
| Observability | kube-prometheus-stack 93.1.1 (Helm), Alertmanager off in dev; Fluent Bit as EKS community add-on v5.1.5 to a Terraform-owned log group (7 days) |
| Secrets | Secrets Manager paths `<project>/<env>/...`; ESO read-only per env prefix; values never in state (ephemeral + write-only); dev recovery window 0 |
| GitOps | Argo CD chart 10.11.6 (v3.5.6) via Terraform; root App of Apps on `gitops/apps` with prune + self-heal; UI at `argocd.dev.domphil.org` behind a shared ALB (IngressGroup `eks-platform-as-code-dev`), admin IP only; public repo, no credentials ([ADR 0002](adr/0002-terraform-vs-argocd.md)) |
| Local tooling | Smart App Control blocks Chocolatey's terraform/helm shims; `~/.bashrc` puts the real binaries first on PATH |

## Open items

- ~~Confirm the GitHub repo~~: `Domphil87/eks-as-code` is public and held
  only an initial README commit; our code was committed on top of it
  (2026-11-10, no force-push). Kept public: Argo CD reads it without
  credentials; the account ID (in the state bucket name) is not a secret.
- **Shared AWS account.** Another project (`ridgeline-fixboard` cluster,
  tag `Project=fixboard`) runs in the same account and region and switched
  the default kubectl context. Use
  `kubectl config use-context arn:aws:eks:us-east-1:<account>:cluster/eks-platform-as-code-dev`
  before verification commands. That project also set the dev context's
  default namespace to `fixboard` in `~/.kube/config`, so commands
  without `-n` fail; reset with
  `kubectl config set-context --current --namespace=default` after
  switching. Its `fixboard` namespace in the dev
  cluster was removed on 2026-11-10 (with your approval) so teardown is
  not blocked by an untracked EFS access point.
- **Spot resilience (from the 2026-11-09 incident).** At the next dev
  rebuild (when replacing the node group is free), add more 2 vCPU / 8 GiB
  types (for example `m6a.large`, `m7i.large`, `m7a.large`,
  `m7i-flex.large`) for deeper Spot pools per AZ; verify availability per
  AZ first. For staging/production, add a small on-demand node group for
  stateful workloads (Prometheus) so an AZ-pinned EBS volume always has a
  node to run on.
- ~~Grafana lists an `Alertmanager` data source although Alertmanager is
  disabled in dev~~: fixed with 4e. Grafana keeps provisioned data sources
  in its (scratch) database, so a one-off `kubectl rollout restart` was
  needed on the running cluster; fresh builds are unaffected.
- **Kubernetes 1.37 upgrade.** Cluster Autoscaler 1.37.0 is now released
  (the reason for staying on 1.36 is gone). Candidate exercise for the
  README's upgrade procedure: control plane, add-ons, node group, then
  `cluster_autoscaler_version` together.
- Install the GitHub CLI before Milestone 6 (Helm 4.1.4 is installed).
- CI runners are not in the cluster endpoint allow-list; decide how CI reaches the API for the platform layer in Milestone 6.
- Activate the `Project` cost allocation tag on or after 2026-10-28 (about 24 hours after bootstrap apply).
- Tighten the pre-existing `github-action-role` trust policy (outside this project).
- Enable MFA on the `aws-cli-terraform-DO-NOT-DELETE` IAM user.
