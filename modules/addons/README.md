# Module: addons

Platform add-ons installed into an existing EKS cluster. It grows one
milestone at a time: 4a adds storage and metrics, 4b adds ingress, DNS
and TLS, 4c adds secrets, 4d adds monitoring and logging, 4e adds node
autoscaling.

```text
EKS managed add-ons                      IAM (Pod Identity)
 ├─ aws-ebs-csi-driver ── controller SA ──> <cluster>-ebs-csi (AmazonEBSCSIDriverPolicyV2)
 ├─ aws-efs-csi-driver ── controller SA ──> <cluster>-efs-csi (AmazonEFSCSIDriverPolicy)
 └─ metrics-server (no AWS permissions)
Helm releases
 ├─ aws-load-balancer-controller (kube-system) ──> <cluster>-aws-load-balancer-controller (official policy)
 ├─ cluster-autoscaler (kube-system) ──> <cluster>-cluster-autoscaler (scale only this cluster's tagged eks-* ASGs)
 ├─ external-dns (external-dns) ──> <cluster>-external-dns (A/AAAA/CNAME/TXT under dns_subdomain only)
 ├─ cert-manager (cert-manager) ──> <cluster>-cert-manager (_acme-challenge TXT under dns_subdomain only)
 ├─ cluster-issuers (local chart): letsencrypt-staging, letsencrypt-prod (Route 53 DNS-01)
 ├─ external-secrets (external-secrets) ──> <cluster>-external-secrets (read <secrets_prefix>/* only)
 ├─ cluster-secret-store (local chart): ClusterSecretStore aws-secrets-manager
 ├─ grafana-admin-secret (local chart): ExternalSecret -> Secret monitoring/grafana-admin
 └─ kube-prometheus-stack (monitoring): Prometheus (gp3 PVC), Grafana, operator,
    kube-state-metrics, node-exporter; Alertmanager off in dev
EKS community add-on
 └─ fluent-bit (fluent-bit) ──> <cluster>-fluent-bit (write to one log group only)
       └─> CloudWatch Logs /aws/eks/<cluster>/containers (retention set)
Secrets Manager
 ├─ <secrets_prefix>/grafana-admin: generated, write-only
 └─ <secrets_prefix>/demo (optional): generated, write-only
StorageClasses
 ├─ gp3 (default): EBS gp3, encrypted, WaitForFirstConsumer, expandable
 └─ efs: one EFS access point per PVC, ReadWriteMany
Route 53 (existing parent zone, read-only lookup)
 ├─ CAA at dns_subdomain: amazon.com + letsencrypt.org
 └─ ACM wildcard *.dns_subdomain (DNS-validated) for ALBs
```

## Files

| File | Contents |
|---|---|
| `iam.tf` | Shared Pod Identity trust policy, CSI controller roles |
| `storage.tf` | EBS and EFS CSI add-ons, StorageClasses |
| `metrics.tf` | metrics-server add-on |
| `dns.tf` | Parent zone lookup, subdomain CAA record, ACM wildcard certificate |
| `load-balancer-controller.tf` | LBC IAM policy, role, Pod Identity association, Helm release |
| `external-dns.tf` | ExternalDNS IAM, Pod Identity association, Helm release |
| `cert-manager.tf` | cert-manager IAM, Pod Identity association, Helm release, ClusterIssuers |
| `policies/aws-load-balancer-controller-v<version>.json` | Upstream LBC policy, unmodified |
| `charts/cluster-issuers/` | Local chart with the two Let's Encrypt ClusterIssuers |
| `external-secrets.tf` | ESO IAM, Pod Identity association, Helm release, ClusterSecretStore |
| `demo-secret.tf` | Optional demo secret (ephemeral password, write-only value) |
| `charts/cluster-secret-store/` | Local chart with the ClusterSecretStore |
| `monitoring.tf` | `monitoring` namespace, Grafana admin secret, kube-prometheus-stack |
| `logging.tf` | Container log group, Fluent Bit IAM and Pod Identity, Fluent Bit add-on |
| `charts/external-secret/` | Reusable local chart: one ExternalSecret |
| `cluster-autoscaler.tf` | Cluster Autoscaler IAM, Pod Identity association, Helm release |

## Inputs

| Name | Default | Description |
|---|---|---|
| `cluster_name` | (none) | Target cluster |
| `cluster_arn` | (none) | Pod Identity roles trust only this cluster |
| `addon_versions` | (none) | Map with aws-ebs-csi-driver, aws-efs-csi-driver, metrics-server |
| `chart_versions` | (none) | Map with aws-load-balancer-controller, external-dns, cert-manager |
| `parent_domain` | (none) | Existing public hosted zone (looked up, apex never modified) |
| `dns_subdomain` | (none) | Subdomain this environment owns, for example `dev.example.com` |
| `secrets_prefix` | (none) | Secrets Manager prefix ESO may read, for example `myproject/dev` |
| `create_demo_secret` | `false` | Create `<secrets_prefix>/demo` |
| `secret_recovery_window_days` | `30` | `0` deletes immediately (dev), otherwise 7–30 |
| `prometheus_retention` | `"2d"` | Prometheus retention |
| `prometheus_storage_gib` | `10` | Prometheus gp3 volume size |
| `container_log_retention_days` | `7` | CloudWatch retention for container logs |
| `cluster_autoscaler_version` | (none) | Image tag; minor must match the cluster (checked at plan time) |
| `cluster_autoscaler_scale_down_unneeded_time` | `"10m"` | Idle time before a node is removed |
| `efs_file_system_id` | `null` | `null` skips the EFS driver and StorageClass |
| `tags` | `{}` | Extra tags |

## Outputs

`ebs_csi_role_arn`, `efs_csi_role_arn`, `lbc_role_arn`,
`external_dns_role_arn`, `cert_manager_role_arn`,
`external_secrets_role_arn`, `cluster_secret_store_name`,
`demo_secret_name`, `fluent_bit_role_arn`, `container_log_group`,
`grafana_admin_secret_name`, `cluster_autoscaler_role_arn`, `dns_subdomain`,
`acm_certificate_arn`, `default_storage_class`, `efs_storage_class`.

## Design notes

- **EKS managed add-ons where AWS offers them, Helm otherwise.** The CSI
  drivers and metrics-server are AWS-built add-ons. The Load Balancer
  Controller, ExternalDNS and cert-manager are pinned Helm charts.
- **Pod Identity, not the node role.** Each controller's service account
  has its own role. The trust policy is restricted to this account and
  this cluster ARN. Helm-installed components use an explicit
  `aws_eks_pod_identity_association`.
- **Route 53 least privilege with record-name conditions.**
  `route53:ChangeResourceRecordSetsNormalizedRecordNames` limits ExternalDNS
  to names under `dns_subdomain` and cert-manager to `_acme-challenge`
  names under it. Neither can change the apex or other subdomains.
- **ExternalDNS `--aws-zone-match-parent`.** The domain filter
  (`dns_subdomain`) also selects hosted zones by suffix, and the parent
  zone does not end in it, so without this flag no zone matches and no
  record is written (found with the first Ingress in 5b). Record names
  stay limited to `dns_subdomain`.
- **Subdomain CAA instead of changing the apex.** Certificate authorities
  use the closest CAA record, so allowing Let's Encrypt at `dns_subdomain`
  leaves the apex policy (Amazon only) unchanged.
- **Two certificate paths.** ALBs can only use ACM certificates, so the
  public HTTPS endpoint uses the ACM wildcard (found automatically by
  host name). cert-manager issues Let's Encrypt certificates as Kubernetes
  Secrets, for in-cluster TLS and anything not behind an ALB.
- **ClusterIssuers in a local chart.** `kubernetes_manifest` needs the CRD
  at plan time, but the CRD only exists after cert-manager is installed.
  A Helm release does not have that limitation.
- **LBC values `region` and `vpcId`.** Set explicitly because pods cannot
  reach instance metadata (hop limit 1).
- **LBC IAM policy file.** Stored unmodified from the upstream release.
  Checkov does not analyse policies loaded with `file()`; this one is the
  vendor-maintained policy for the pinned version.
- **Secrets never pass through Terraform state.** ESO reads Secrets
  Manager at runtime. The demo secret's value comes from an `ephemeral`
  `random_password` written to `secret_string_wo` (write-only), so it is
  not in the plan, the state or Git. Increase `secret_string_wo_version`
  to write a new value.
- **One ClusterSecretStore per environment, limited by IAM.** The ESO role
  can only read `<secrets_prefix>/*`, so dev cannot read staging secrets.
  Per-team restrictions are added with the team namespaces (Milestone 5).
- **Grafana's password comes through ESO.** It is generated into Secrets
  Manager and copied into `monitoring/grafana-admin` by an ExternalSecret
  before Grafana starts.
- **EKS-specific Prometheus settings.** Controller manager, scheduler,
  etcd and kube-proxy metrics are not reachable on EKS, so their scrape
  targets are disabled instead of showing as permanently down.
  ServiceMonitors are picked up from every namespace for team apps.
- **Prometheus volume is deleted with Prometheus**
  (`persistentVolumeClaimRetentionPolicy.whenDeleted = Delete`), so no
  EBS volume is left behind at teardown.
- **Fluent Bit as an EKS community add-on.** Namespace and service account
  are fixed (`fluent-bit`/`fluent-bit`); the add-on declares no Pod
  Identity configuration, so a separate association is created. Fluent
  Bit 5.x reads Pod Identity credentials. Terraform creates the log
  group (with retention) and IAM only allows writing to it.
- **Cluster Autoscaler version pinned to the cluster.** The chart's default
  image follows the newest Kubernetes release; a `precondition` fails the
  plan if `cluster_autoscaler_version` does not match the cluster's minor
  version. Bump both together when upgrading Kubernetes.
- **Cluster Autoscaler least privilege.** Describe calls are account-wide
  (AWS does not support narrowing them); `eks:DescribeNodegroup` is limited
  to this cluster; scale actions are limited to `eks-*` Auto Scaling
  groups that carry this cluster's `k8s.io/cluster-autoscaler/*` tags.
  Terraform ignores the node group's `desired_size`, which the autoscaler
  owns.
- **No customer KMS key.** Secrets use the AWS-managed `aws/secretsmanager`
  key, which needs no extra IAM permission or KMS cost.
- **Volume tags.** EBS volumes are created by the driver, not Terraform,
  so the driver's `extraVolumeTags` carries the provider default tags.
- **`deleteAccessPointRootDir = true`.** Deleting an EFS PVC also deletes
  its data, so dev does not accumulate billed storage.
- **gp2 is left alone.** EKS still creates a legacy `gp2` StorageClass
  (in-tree provisioner, not the default). New PVCs use `gp3`.

## Upgrading the Load Balancer Controller

1. Download `docs/install/iam_policy.json` from the new release tag into
   `policies/aws-load-balancer-controller-v<version>.json`.
2. Change `chart_versions["aws-load-balancer-controller"]`.
3. Plan: review the policy diff and the Helm release change together.

## Teardown warning

Resources created by controllers are **not** in Terraform state:

- EBS volumes and EFS access points from PVCs: delete PVCs first.
- ALBs/NLBs and their security groups from Ingresses and Services:
  delete those Kubernetes objects first and wait until the load
  balancers are gone, or the VPC destroy fails and the ALB keeps billing.
- Route 53 records from ExternalDNS: removed automatically when the
  Ingress is deleted (`policy = sync`) while ExternalDNS is still running.
