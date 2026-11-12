# EKS Platform as Code

A repeatable, secure, version-controlled Amazon EKS platform built with
Terraform, GitHub Actions, Helm and Argo CD. It replaces a manually configured
cluster with code: infrastructure is provisioned in layers, platform add-ons
are pinned Helm releases, and application teams deploy through Git (GitOps).

> **Status: Milestone 4 complete (2026-11-09).** All platform add-ons are
> deployed in dev: storage, metrics-server, ingress/DNS/TLS, secrets,
> monitoring, logging and Cluster Autoscaler. Acceptance tests #8, #9, #10
> and #12 pass. Milestone 5 (GitOps with Argo CD) is in progress: the code
> is on GitHub (5a) and Argo CD (5b) is deployed and syncing from it.
> Team namespaces (5c) are in Git; next: the sample app (5d).
> See [docs/project-plan.md](docs/project-plan.md) for progress.

## Deployment status

| Component | In code | Deployed to AWS |
|---|---|---|
| Bootstrap: S3 state bucket and budget alert | ✅ | ✅ (own state in S3: `bootstrap/terraform.tfstate`) |
| Network layer (dev) | ✅ | ✅ Rebuilt 2026-11-09 (NAT about $0.05/hour) |
| Cluster layer (dev) | ✅ | ✅ Rebuilt 2026-11-09, 3 Spot nodes in 1a/1b/1c (about $0.20/hour) |
| Platform add-ons (dev): 4a storage + metrics | ✅ | ✅ Rebuilt 2026-11-09 |
| Platform add-ons (dev): 4b ingress, DNS, TLS | ✅ | ✅ Rebuilt 2026-11-09 |
| Platform add-ons (dev): 4c secrets | ✅ | ✅ 2026-11-09, acceptance test #8 passed |
| Platform add-ons (dev): 4d monitoring + logging | ✅ | ✅ 2026-11-09, acceptance tests #9 and #10 passed |
| Platform add-ons (dev): 4e Cluster Autoscaler | ✅ | ✅ 2026-11-09, acceptance test #12 passed |
| GitOps 5a: code published to GitHub | ✅ | n/a (pushed 2026-11-10) |
| GitOps 5b: Argo CD, root App of Apps | ✅ | ✅ 2026-11-10, `https://argocd.dev.domphil.org` (admin IP only), ALB about $0.025/hour |
| GitOps 5c: team namespaces, RBAC, quotas, Argo CD projects | ✅ | ✅ 2026-11-11, isolation verified |
| GitOps 5d: sample app | ⬜ | ⬜ |
| CI/CD pipeline | ⬜ | ⬜ |
| Staging | ⬜ | ⬜ |

Dev is torn down at the end of each working session and rebuilt from code
(network → cluster → platform), so "Deployed" reflects the current session.

## Architecture (target)

```text
                    GitHub (Domphil87/eks-as-code)
          PR: fmt / validate / TFLint / Checkov / plan
          merge: apply (OIDC, no stored AWS keys)
                         │                     ▲ Argo CD pulls
                         ▼                     │ app manifests
┌──────────────────────── AWS account ─────────┼────────────────────┐
│  S3: Terraform state (bootstrap)             │                    │
│  ┌──────────────── VPC 10.10.0.0/16 (dev) ───┼──────────────────┐ │
│  │  Public subnets ×3 AZ:  ALB, NAT gateway  │                  │ │
│  │  Private subnets ×3 AZ:                   │                  │ │
│  │    EKS managed nodes ── Argo CD ──────────┘                  │ │
│  │      add-ons: LB Controller, ExternalDNS, cert-manager,      │ │
│  │      EBS/EFS CSI, ESO, Prometheus/Grafana, Fluent Bit,       │ │
│  │      metrics-server, Cluster Autoscaler                      │ │
│  │    EFS mount targets                                         │ │
│  └──────────────────────────────────────────────────────────────┘ │
│  Route 53 · ACM/cert-manager · Secrets Manager · CloudWatch · ECR │
└───────────────────────────────────────────────────────────────────┘
```

Terraform state is split into three layers per environment:
**network → cluster → platform** ([ADR 0001](docs/adr/0001-layered-terraform-state.md)).

## Repository layout

```text
eks-platform-as-code/
├── bootstrap/            # ✅ One-time: state bucket and budget (local state at first)
├── modules/              # Reusable modules: network ✅, eks ✅, addons ✅, gitops ✅
├── envs/                 # Root configs per environment and layer
│   ├── dev/{network,cluster,platform}/   ✅
│   └── staging/{network,cluster,platform}/   ⬜
├── gitops/               # Deployed by Argo CD: apps/ ✅ (5b), teams/ ✅ (5c), sample app ⬜
├── .github/workflows/    # ⬜ CI/CD
├── docs/
│   ├── project-plan.md   # ✅ Milestones and decisions
│   └── adr/              # ✅ Architecture Decision Records
├── .tflint.hcl           # ✅ Lint rules shared by all Terraform folders
├── .gitattributes        # ✅ LF line endings (Windows vs. Linux CI)
└── .gitignore            # ✅ Keeps state, plans, secrets and private tfvars out of Git
```

## Prerequisites and tool versions

| Tool | Version used | Needed from | Install |
|---|---|---|---|
| Terraform | 1.16.7, pinned in Chocolatey (constraint `~> 1.15`) | Milestone 1 | `choco upgrade terraform --version 1.16.7` (admin) |
| AWS CLI | v2 (2.35.x) | Milestone 1 | already installed |
| Docker | 29.x | Milestone 1 (runs TFLint/Checkov) | already installed |
| TFLint | 0.65.0, AWS ruleset 0.50.0 | Milestone 1 | via Docker (below) |
| Checkov | 3.3.30 | Milestone 1 | via Docker (below) |
| kubectl | 1.37 client | Milestone 3 | already installed |
| Helm | 4.1.4 | Milestone 4b | already installed (Chocolatey) |
| GitHub CLI | latest | Milestone 6 | `winget install GitHub.cli` |

**Terraform version choice.** We use **1.16.7**, the latest patch of the
mature 1.16 line, rather than 1.17.0 (released 2026-10-21). TFLint 0.65.0
officially supports Terraform up to 1.16. The Chocolatey pin
(`choco pin add -n terraform --version 1.16.7`) stops `choco upgrade all`
from silently moving to 1.17. CI will use the same version (Milestone 6).
To upgrade later, remove the pin with `choco pin remove -n terraform`, then
upgrade on your laptop and in CI together.

## Milestone 1: bootstrap the state backend

Details, verification steps and design trade-offs:
[bootstrap/README.md](bootstrap/README.md).

```powershell
cd C:\Users\domin\eks-platform-as-code

# 1. Format and lint (no AWS access needed)
terraform fmt -check -recursive
docker run --rm -v "${PWD}:/data" -w /data --entrypoint /bin/sh `
  ghcr.io/terraform-linters/tflint:v0.65.0 `
  -c "tflint --init --config /data/.tflint.hcl && tflint --recursive --config /data/.tflint.hcl"

# 2. Security scan (no AWS access needed)
docker run --rm -v "${PWD}:/tf" bridgecrew/checkov:3.3.30 -d /tf/bootstrap --framework terraform --compact

# 3. Init, validate, plan (plan reads AWS but changes nothing)
cd bootstrap
terraform init
terraform validate
terraform plan -out=bootstrap.tfplan

# 4. Apply ONLY after reviewing the plan
terraform apply bootstrap.tfplan
```

## Milestone 2: dev network layer

Module details: [modules/network/README.md](modules/network/README.md).
Settings: [envs/dev/network/terraform.tfvars](envs/dev/network/terraform.tfvars).

| | dev |
|---|---|
| VPC | `10.10.0.0/16` |
| AZs | `us-east-1a/b/c` (zone IDs use1-az1/az2/az4; `us-east-1e` = use1-az3 is avoided because it lacks EKS support) |
| Private subnets | `10.10.0.0/19`, `10.10.32.0/19`, `10.10.64.0/19` |
| Public subnets | `10.10.96.0/24`, `10.10.97.0/24`, `10.10.98.0/24` |
| NAT | 1 shared (about $0.05/hour including its public IPv4 address) |

```powershell
cd C:\Users\domin\eks-platform-as-code\envs\dev\network
terraform init
terraform validate
terraform plan -out=network.tfplan
terraform apply network.tfplan      # only after review
```

## Milestone 3: dev cluster layer

Module details: [modules/eks/README.md](modules/eks/README.md).
Settings: [envs/dev/cluster/terraform.tfvars](envs/dev/cluster/terraform.tfvars).
Your IP allow-list lives in the git-ignored `envs/dev/cluster/admin-access.auto.tfvars`
(copy it from the `.example` file).

| | dev |
|---|---|
| Kubernetes | 1.36 (standard support until 2027-08-01), `upgrade_policy = STANDARD` |
| API endpoint | Private + public, restricted to your IP /32 |
| Auth | EKS access entries (API mode); your IAM user is cluster-admin |
| Nodes | Managed node group, 3 × Spot (t3a/t3/m5a/m6i/m5 `.large`), min 3, max 6, AL2023 |
| Add-ons | vpc-cni, kube-proxy, eks-pod-identity-agent, coredns (pinned) |
| Storage | EFS file system + 3 mount targets (CSI driver installed in Milestone 4a) |

```powershell
cd C:\Users\domin\eks-platform-as-code\envs\dev\cluster
terraform init
terraform plan -out=cluster.tfplan
terraform apply cluster.tfplan          # about 10-15 minutes
aws eks update-kubeconfig --region us-east-1 --name eks-platform-as-code-dev
kubectl get nodes -L topology.kubernetes.io/zone
```

Verified on 2026-10-30: 3 nodes `Ready` (v1.36.5, one per AZ, all `SPOT`),
4 add-ons `ACTIVE`, 3 EFS mount targets `available`, IMDSv2 `required` with
hop limit 1 and no public IPs on nodes, drift check clean.

## Milestone 4a: storage and metrics (dev platform layer)

Module details: [modules/addons/README.md](modules/addons/README.md).
Settings: [envs/dev/platform/terraform.tfvars](envs/dev/platform/terraform.tfvars).

| Component | How | AWS permissions |
|---|---|---|
| EBS CSI driver | EKS add-on `v1.67.2-eksbuild.1` | Pod Identity role, `AmazonEBSCSIDriverPolicyV2` |
| EFS CSI driver | EKS add-on `v3.5.4-eksbuild.1` | Pod Identity role, `AmazonEFSCSIDriverPolicy` |
| metrics-server | EKS add-on `v0.9.0-eksbuild.14` | none |
| StorageClass `gp3` (default) | Terraform `kubernetes` provider 3.4.0 | |
| StorageClass `efs` | Terraform `kubernetes` provider 3.4.0 | |

```powershell
cd C:\Users\domin\eks-platform-as-code\envs\dev\platform
terraform init
terraform plan -out=platform.tfplan
terraform apply platform.tfplan
kubectl get storageclass
kubectl top nodes
```

The `kubernetes` provider connects to the cluster API, so `plan` only works
from an IP in the cluster's endpoint allow-list.

Verified on 2026-10-30: 3 add-ons `ACTIVE`, Pod Identity associations for
`ebs-csi-controller-sa` and `efs-csi-controller-sa`, all CSI and
metrics-server pods `Running`, `gp3 (default)` and `efs` StorageClasses,
`kubectl top nodes` working, drift check clean.

## Milestone 4b: ingress, DNS and TLS (dev platform layer)

| Component | How | AWS permissions (Pod Identity) |
|---|---|---|
| AWS Load Balancer Controller | Helm chart 3.6.2 (`kube-system`) | Official upstream policy for v3.6.2 |
| ExternalDNS | Helm chart 1.23.0 (`external-dns`) | Route 53 A/AAAA/CNAME/TXT under `dev.domphil.org` only |
| cert-manager | Helm chart v1.21.3 (`cert-manager`) | Route 53 `_acme-challenge` TXT under `dev.domphil.org` only |
| ClusterIssuers `letsencrypt-staging`, `letsencrypt-prod` | Local Helm chart | (uses cert-manager's role) |
| ACM certificate `*.dev.domphil.org` | Terraform, DNS-validated | Free; used by ALBs |
| CAA record `dev.domphil.org` | Terraform | Allows `amazon.com` and `letsencrypt.org` for dev only |

The `domphil.org` hosted zone already existed and is **not** managed by
this project; the apex records (including its CAA) are never changed.
Load balancers are only created when an Ingress or Service asks for one
(Milestone 5 sample app), so 4b itself adds no hourly cost.

Verified on 2026-10-31: all controller pods `Running` with no AWS auth
errors, 5 Pod Identity associations, IngressClass `alb`, both
ClusterIssuers `Ready` (ACME account registered), ACM certificate
`ISSUED`, `dev.domphil.org` CAA present and apex records unchanged, drift
check clean.

## Milestone 4c: secrets (dev platform layer)

| Component | How | AWS permissions (Pod Identity) |
|---|---|---|
| External Secrets Operator | Helm chart 2.14.0 (`external-secrets`) | Read-only on `eks-platform-as-code/dev/*` in Secrets Manager |
| ClusterSecretStore `aws-secrets-manager` | Local Helm chart | (uses ESO's role) |
| Demo secret `eks-platform-as-code/dev/demo` | Terraform, value generated ephemerally and written write-only | about $0.40/month, prorated |

Secret **values** never appear in Git, the Terraform plan or state. Apps
request them with an `ExternalSecret` that references the
ClusterSecretStore; ESO creates and refreshes the Kubernetes Secret.

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: demo
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: aws-secrets-manager
  target:
    name: demo            # Kubernetes Secret to create
  dataFrom:
    - extract:
        key: eks-platform-as-code/dev/demo
```

**Acceptance test #8 (2026-11-09): passed.**

| Check | Result |
|---|---|
| ESO pods (controller, webhook, cert-controller) | `Running` |
| ClusterSecretStore `aws-secrets-manager` | `Valid` ("store validated") |
| `ExternalSecret` for `eks-platform-as-code/dev/demo` | `SecretSynced`; Secret has `username` and `password` |
| Value matches Secrets Manager | Yes (SHA-256 compared; value never printed) |
| Password in Terraform state | 0 occurrences |
| Read `eks-platform-as-code/staging/demo` | `AccessDeniedException` from the ESO role (least privilege works) |

To repeat it, apply the `ExternalSecret` above in a test namespace, run
`kubectl get externalsecret -n <ns>`, then delete the namespace.

## Milestone 4d: monitoring and logging (dev platform layer)

| Component | How | Notes |
|---|---|---|
| kube-prometheus-stack | Helm chart 93.1.1 (`monitoring`) | Prometheus (2d retention, 10 GiB gp3), Grafana, kube-state-metrics, node-exporter; Alertmanager off in dev |
| Grafana admin login | Secrets Manager → ESO → `monitoring/grafana-admin` | Generated, never in Git or state |
| Fluent Bit | EKS community add-on `v5.1.5-eksbuild.2` (`fluent-bit`) | Pod Identity role can only write to the log group below |
| Log group `/aws/eks/eks-platform-as-code-dev/containers` | Terraform | 7-day retention; one stream per namespace.pod.container |

Open Grafana (user `admin`):

```bash
kubectl get secret -n monitoring grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d; echo
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# then browse to http://localhost:3000
```

**Acceptance test #9, metrics (2026-11-09): passed.** All 8 scrape jobs
100% up (apiserver, kubelet, coredns, kube-state-metrics, node-exporter,
grafana, operator, prometheus); per-node CPU data present; Grafana 13.3
with 24 dashboards; login with the ESO-synced password returns 200 (wrong
password 401); a query through Grafana's Prometheus data source returns
live data.

**Acceptance test #10, logs (2026-11-09): passed.** Container logs from
all 6 namespaces arrive in `/aws/eks/eks-platform-as-code-dev/containers`
as `namespace.pod.container` streams with Kubernetes metadata; 0 fallback
streams; no credential errors in Fluent Bit.

```bash
MSYS_NO_PATHCONV=1 aws logs describe-log-streams \
  --log-group-name /aws/eks/eks-platform-as-code-dev/containers \
  --order-by LastEventTime --descending --max-items 5 --query "logStreams[].logStreamName"
```

### Incident during 4d: Spot interruption stranded Prometheus (2026-11-09)

Two Spot interruptions removed both nodes in us-east-1a, and Spot launches
there failed for several minutes (`UnfulfillableCapacity`), although the
placement score was 9/10. Fluent Bit, Grafana and the controllers moved
to the remaining nodes, but Prometheus stayed `Pending`: its EBS volume
lives in us-east-1a and EBS cannot attach across AZs.

Fixed in dev by deleting the Prometheus PVC and pod; the StatefulSet
created a new volume in us-east-1b (about 30 minutes of metrics lost),
and the `Delete` reclaim policy removed the old volume. Follow-ups are
in [docs/project-plan.md](docs/project-plan.md).

## Milestone 4e: Cluster Autoscaler (dev platform layer)

| Component | How | AWS permissions (Pod Identity) |
|---|---|---|
| Cluster Autoscaler v1.36.2 | Helm chart 9.60.0 (`kube-system`), ASG auto-discovery | Describe (account-wide, not narrowable); scale only `eks-*` ASGs tagged for this cluster |

Node group limits stay in the cluster layer (dev: min 3, max 6); Terraform
ignores `desired_size`, which the autoscaler owns. Dev removes a node after
5 idle minutes. A plan-time check fails if the autoscaler's minor version
does not match the cluster's.

**Acceptance test #12 (2026-11-09): passed.**

| Step | Result |
|---|---|
| Deployment of 4 × 1 vCPU `pause` pods (3 nodes had about 1.4 vCPU free each) | 3 Running, 1 `Pending` ("3 Insufficient cpu") |
| Autoscaler reaction | `TriggeredScaleUp … 3->4 (max: 6)` within about 10 s |
| New node | Spot t3a.large in us-east-1a; all 4 pods Running **61 s** after the test started |
| Delete the test | Idle node removed 5 min later (`ScaleDownDeleteTime` 23:35:23); back to 3 nodes, one per AZ; ASG 3/3/6 |
| Terraform drift (cluster, platform) after scaling | None |

To repeat it: apply a Deployment whose CPU requests exceed free capacity,
watch `kubectl get events -n <ns>` for `TriggeredScaleUp`, then delete it
and watch `kubectl get nodes` return to the minimum.

## Milestone 5b: Argo CD (dev platform layer)

**Status: deployed 2026-11-10 and verified.**

| Component | How | Exposure |
|---|---|---|
| Argo CD v3.5.6 | Helm chart 10.11.6 (`argocd`), Terraform `modules/gitops` | `https://argocd.dev.domphil.org` via ALB, ACM wildcard, **admin IP only** |
| Root Application ("App of Apps") | Local chart, automated sync with prune + self-heal | Watches `gitops/apps` on `main` of this (public) repo, no credentials |

Terraform owns the platform and Argo CD; Argo CD owns everything under
`gitops/` ([ADR 0002](docs/adr/0002-terraform-vs-argocd.md)). Your admin IP
goes in the git-ignored `envs/dev/platform/admin-access.auto.tfvars`
(template: `admin-access.auto.tfvars.example`). The ALB is in the
IngressGroup `eks-platform-as-code-dev`, which the sample app (5d) will
share: about $0.025/hour while it exists.

Log in (user `admin`):

```bash
terraform output -raw argocd_admin_password_command   # run the printed command
# then open https://argocd.dev.domphil.org
kubectl -n argocd get applications                    # root: Synced, Healthy
```

(The `gitops-smoke-test` ConfigMap used to verify 5b was replaced by the
`teams` Application in 5c.)

**Verification (2026-11-10):**

| Check | Result |
|---|---|
| Argo CD pods | 5/5 Running; root Application `Synced` / `Healthy` |
| GitOps loop | `gitops-smoke-test` ConfigMap created from Git |
| Self-heal | Manual edit of the ConfigMap reverted to the Git value within seconds |
| DNS | ExternalDNS created `argocd.dev.domphil.org` (A/AAAA alias) and its TXT ownership records |
| HTTPS | 200; HTTP → 301 to HTTPS; certificate `*.dev.domphil.org` (Amazon); TLS 1.3 negotiated, TLS 1.1 refused |
| Login | Correct admin password 200, wrong password 401 |
| Source IP limit | ALB security group allows only the admin /32 on 80/443; a request from the cluster's NAT IP timed out |
| ALB tags | Project, Environment, Owner, CostCenter, ManagedBy, Layer |
| Terraform drift | None (`plan -detailed-exitcode` = 0) |

**Fix found during 5b:** ExternalDNS (from 4b) had never written a
record. Its domain filter (`dev.domphil.org`) also selects hosted zones by
suffix, and the zone is `domphil.org`, so no zone matched; the log only said
"All records are already up to date". Adding `--aws-zone-match-parent`
fixed it. The gitops module also takes its ALB tags as a plain input
(not a data source), so add-on changes don't make Argo CD show a
spurious update in plans.

## Milestone 5c: team namespaces (GitOps)

**Status: deployed 2026-11-11 and verified.**

The root Application now syncs a child Application, `teams`, which
deploys `gitops/teams/<team>/` for **team-a** and **team-b**: a
namespace with Pod Security `restricted`, a ResourceQuota and LimitRange,
a RoleBinding that gives the group `<team>-developers` `edit` in that
namespace only, and an Argo CD AppProject that limits the team's
applications to this repo and its own namespace. Details:
[gitops/README.md](gitops/README.md).

**Verification (2026-11-11):** Argo CD created everything within seconds
of the push (`root` and `teams` both `Synced` / `Healthy`) and pruned the
5b smoke-test ConfigMap.

| Check | Result |
|---|---|
| RBAC (as `team-a-developers`) | Can create Deployments in team-a; cannot read or write team-b, create RoleBindings, change quota or LimitRange, create namespaces or read kube-system Secrets |
| Pod Security | Privileged pod rejected (`violates PodSecurity "restricted:latest"`); compliant pod admitted |
| LimitRange | Pod without resources got the defaults (50m / 64 Mi request, 250m / 256 Mi limit); a container with a 3-CPU limit was rejected (max 1) |
| Quota | Deployment of 3 × 1 CPU stopped at 1/3 replicas (`exceeded quota: requests.cpu`); LoadBalancer Service rejected |
| Argo CD project | Application in project `team-a` targeting namespace team-b refused (`InvalidSpecError`: destination not allowed) |
| Self-heal | Deleted team-b RoleBinding was recreated by Argo CD within seconds |

## Cost management

- An **AWS Budget alerts you; it does not cap spending.** Resources keep
  running and billing after a budget is exceeded, and billing data lags by
  hours.
- Bootstrap costs cents per month. A running dev cluster costs roughly
  **$0.30/hour (about $7/day)**: control plane, NAT gateway, 3 nodes and an ALB.
- Provision dev, test, and **tear it down the same day**. Check for leftover
  load balancers, EBS volumes and Elastic IPs before destroying the VPC.

## Security notes

- No AWS keys in GitHub: CI will use GitHub OIDC with short-lived credentials
  (Milestone 6).
- Never commit `*.tfstate`, `*.tfplan`, or private `*.tfvars`. `.gitignore`
  enforces this.
- Worker nodes run only in private subnets.

## Teardown (safe order)

Reverse of creation: GitOps apps → platform → cluster → network → bootstrap
(last, and only after migrating its state back to local).

**Current end-of-day teardown (platform + cluster + network; bootstrap stays):**

```powershell
# From 5b: remove everything Argo CD deployed first (its finalizer deletes
# the apps, their Ingresses and ALBs) while the controllers still run.
kubectl -n argocd delete application root --wait=true
kubectl get pvc -A                            # must be empty: PVC volumes are not in Terraform state
kubectl get ingress -A                        # only argocd/argocd-server (removed by the platform destroy); after the destroy, check no ALB is left:
aws elbv2 describe-load-balancers --query "LoadBalancers[].LoadBalancerName"
cd C:\Users\domin\eks-platform-as-code\envs\dev\platform
terraform plan -destroy -out=destroy.tfplan   # review: only add-ons, roles, StorageClasses
terraform apply destroy.tfplan

cd ..\cluster
terraform plan -destroy -out=destroy.tfplan   # review: only cluster resources
terraform apply destroy.tfplan                # about 10 minutes

cd ..\network
terraform plan -destroy -out=destroy.tfplan   # review: 26 to destroy
terraform apply destroy.tfplan
```

Before destroying the network, confirm nothing else is still using the VPC.
Load balancers created by Kubernetes (from Milestone 4b) must be deleted
first, or the VPC destroy will fail on leftover ENIs and security groups.

## Documentation

- [Project plan](docs/project-plan.md)
- [ADR 0001: layered Terraform state](docs/adr/0001-layered-terraform-state.md)
- [Bootstrap guide](bootstrap/README.md)
