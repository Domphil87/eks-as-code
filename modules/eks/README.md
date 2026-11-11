# Module: eks

Creates an EKS cluster with a managed node group, core add-ons, access
entries, control-plane logging and an EFS file system.

```text
EKS control plane (AWS-managed)
 ├─ API endpoint: private + public (restricted CIDRs)
 ├─ Auth mode API: access entries → AmazonEKSClusterAdminPolicy for listed principals
 ├─ Logs → CloudWatch /aws/eks/<name>/cluster (retention set)
 └─ Managed add-ons: vpc-cni, kube-proxy, eks-pod-identity-agent (before nodes), coredns (after)
Managed node group "default" (private subnets, AL2023, launch template: IMDSv2 + hop limit 1, encrypted gp3)
EFS (encrypted, elastic throughput) + mount target per subnet + SG allowing NFS from the cluster SG
```

## Files

| File | Contents |
|---|---|
| `iam.tf` | Cluster role (EKS service) and node role (EC2) |
| `main.tf` | Log group, cluster, access entries, core add-ons |
| `nodes.tf` | Launch template and managed node group |
| `efs.tf` | EFS file system, mount targets, security group |

## Inputs

| Name | Default | Description |
|---|---|---|
| `cluster_name` | (none) | Cluster name and resource prefix |
| `kubernetes_version` | (none) | For example `1.36` |
| `vpc_id`, `private_subnet_ids` | (none) | From the network layer |
| `endpoint_public_access` | `true` | Public API endpoint on or off |
| `endpoint_public_access_cidrs` | (none) | Allowed CIDRs (`0.0.0.0/0` is rejected) |
| `cluster_admin_principal_arns` | (none) | IAM ARNs that get cluster-admin |
| `enabled_log_types` | `["audit","authenticator"]` | Control-plane logs |
| `log_retention_days` | `7` | CloudWatch retention |
| `addon_versions` | (none) | Map with vpc-cni, kube-proxy, coredns, eks-pod-identity-agent |
| `node_instance_types` | (none) | Same-size types |
| `node_capacity_type` | (none) | `ON_DEMAND` or `SPOT` |
| `node_min_size` / `node_desired_size` / `node_max_size` | (none) | Scaling bounds |
| `node_disk_size_gib` | `30` | Root volume size |
| `enable_efs` | `true` | Create EFS |
| `tags` | `{}` | Extra tags |

## Outputs

`cluster_name`, `cluster_arn`, `cluster_version`, `cluster_endpoint`,
`cluster_certificate_authority_data`, `cluster_security_group_id`,
`oidc_issuer_url`, `node_role_arn`, `node_group_name`,
`node_group_asg_names`, `efs_file_system_id`.

## Design notes

- **`bootstrap_self_managed_addons = false`.** EKS installs no unmanaged
  defaults. All four core add-ons are managed, at pinned versions.
- **Add-on ordering.** vpc-cni, kube-proxy and pod-identity-agent are
  DaemonSets that nodes need to become Ready, so they are installed before
  the node group. CoreDNS is a Deployment and needs nodes, so it comes after.
- **IMDS hop limit 1.** Pods cannot reach the instance metadata service
  through the extra network hop, so they cannot use the node role. AWS
  permissions for add-ons come from EKS Pod Identity (platform layer).
- **VPC CNI on the node role (accepted trade-off).** `aws-node` runs on the
  host network and needs credentials before other components start, so
  `AmazonEKS_CNI_Policy` is attached to the node role.
- **`upgrade_policy = STANDARD`.** Prevents automatic enrolment in extended
  support, which costs about 6x more for the control plane.
- **`ignore_changes = [scaling_config[0].desired_size]`.** Cluster Autoscaler
  owns the node count after creation.
- **Managed node groups and access entries.** In `API` auth mode, EKS
  creates the node role's access entry automatically for managed node groups.

## Checkov skips

| Check | Reason |
|---|---|
| CKV_AWS_39: public endpoint | Needed for laptop kubectl; restricted to specific CIDRs |
| CKV_AWS_58: secrets KMS | EKS default envelope encryption (AWS-owned key); no KMS cost |
| CKV_AWS_37: all log types | Only audit and authenticator in dev, for cost |
| CKV_AWS_339: supported version | Checkov 3.3.30 list stops at 1.35; AWS reports 1.36 as standard support |
| CKV_AWS_158 / CKV_AWS_338: log group KMS and 1-year retention | Cost; 7 days in dev |
| CKV_AWS_184: EFS customer KMS key | AWS-managed EFS key; no KMS cost |
| CKV2_AWS_18: EFS backup | Disposable dev data |
