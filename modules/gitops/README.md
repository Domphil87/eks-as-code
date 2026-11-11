# Module: gitops

Installs Argo CD and the root "App of Apps" Application. After this,
everything under `apps_path` in Git is deployed by Argo CD, not by
Terraform ([ADR 0002](../../docs/adr/0002-terraform-vs-argocd.md)).

```text
Your browser (allowed_cidrs only)
   │ HTTPS (ACM wildcard, TLS 1.2+)
   ▼
ALB (IngressGroup alb_group_name, created by the Load Balancer Controller)
   │ HTTP inside the VPC
   ▼
argocd-server ──> Application "root" ──> Git: <repo_url>/<apps_path>
                                          └─ child manifests / Applications
ExternalDNS ──> Route 53: <hostname> → ALB
```

## Files

| File | Contents |
|---|---|
| `main.tf` | `argocd` namespace, Argo CD Helm release with the ALB Ingress, root Application |
| `charts/root-app/` | Local chart with the root Application |

## Inputs

| Name | Default | Description |
|---|---|---|
| `argocd_chart_version` | (none) | argo-cd chart version |
| `hostname` | (none) | UI host name, covered by the ACM certificate |
| `acm_certificate_arn` | (none) | Certificate for the ALB HTTPS listener |
| `allowed_cidrs` | (none) | Source IPs allowed to reach the ALB; `0.0.0.0/0` is rejected |
| `alb_group_name` | (none) | IngressGroup; Ingresses with the same name share one ALB |
| `repo_url` | (none) | Git repository (public: no credentials needed) |
| `target_revision` | `"main"` | Branch the root Application tracks |
| `apps_path` | `"gitops/apps"` | Folder with child manifests |
| `tags` | `{}` | Extra ALB tags (provider default tags are always added) |

## Outputs

`argocd_namespace`, `argocd_url`, `root_app_name`.

## Design notes

- **TLS ends at the ALB.** The ALB uses the environment's ACM wildcard,
  redirects HTTP to HTTPS and uses the `ELBSecurityPolicy-TLS13-1-2-2021-06`
  policy. Argo CD runs with `server.insecure = true` so it does not
  redirect again; traffic from the ALB to the pod stays inside the VPC.
- **Admin-only ALB.** `inbound-cidrs` limits the ALB security group to
  `allowed_cidrs`. Argo CD also requires a login.
- **One shared ALB.** `group.name` lets later Ingresses (the sample app)
  join the same ALB instead of creating one each. The ALB has one
  security group, so source IP rules from all Ingresses in the group are
  combined: an Ingress that opens the group to everyone also opens the
  Argo CD UI. Public apps must use a different group.
- **UI and `argocd` CLI over HTTPS only.** No separate gRPC target group;
  use `argocd login <host> --grpc-web`.
- **Login.** Dex (SSO) is disabled in dev. The chart generates an admin
  password in `argocd-initial-admin-secret`.
- **Root Application in a local chart.** Its CRD exists only after the
  Argo CD release, so `kubernetes_manifest` cannot plan it (same pattern
  as the ClusterIssuers).
- **Automated sync with prune and self-heal.** Git is the source of
  truth: manual cluster changes to managed objects are reverted.
- **Version.** Chart 10.11.6 (Argo CD v3.5.6). Argo CD 3.5 is tested on
  Kubernetes 1.33–1.36; Argo CD 3.6 (chart 10.12+) adds 1.37, so move up
  with the Kubernetes 1.37 upgrade.

## Teardown warning

The root Application has the `resources-finalizer.argocd.argoproj.io`
finalizer: deleting it deletes everything Argo CD deployed, including
Ingresses (and so their ALBs and DNS records). Do this **first**, while
Argo CD, the Load Balancer Controller and ExternalDNS are still running:

```bash
kubectl -n argocd delete application root --wait=true
kubectl get ingress -A          # expect: argocd-server only (Terraform-managed)
```

Then destroy the platform layer, which removes the Argo CD Ingress and
its ALB through the Load Balancer Controller.
