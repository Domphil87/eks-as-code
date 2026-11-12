# GitOps

Everything in this folder is deployed by **Argo CD**, not Terraform
([ADR 0002](../docs/adr/0002-terraform-vs-argocd.md)). Commit and push to
`main`; Argo CD applies the change within about three minutes.

```text
gitops/
├── apps/                  ← watched by the root Application ("App of Apps")
│   ├── teams.yaml            child Application for gitops/teams (5c)
│   └── team-a-hello.yaml     team-a's sample app, in the team-a project (5d)
├── workloads/             ← applications, one folder per team and app (5d)
│   └── team-a/hello/         Kustomize: Deployment, Service, Ingress, HPA, PDB, EFS PVC
└── teams/                 ← one folder per team (5c)
    ├── team-a/
    │   ├── namespace.yaml    Pod Security "restricted" (enforce/warn/audit)
    │   ├── quota.yaml        ResourceQuota + LimitRange defaults
    │   ├── rbac.yaml         group team-a-developers → "edit" in team-a only
    │   └── appproject.yaml   Argo CD project: this repo, team-a namespace only
    └── team-b/               same for team-b
```

## Teams

| Guardrail | team-a / team-b |
|---|---|
| Pod Security | `restricted` enforced (no privileged pods, root, host access; seccomp required) |
| Quota | requests 2 CPU / 4 Gi, limits 4 CPU / 8 Gi, 20 pods, 5 PVCs / 20 Gi, no LoadBalancer or NodePort Services |
| Container defaults | request 50m / 64 Mi, limit 250m / 256 Mi, max 1 CPU / 2 Gi per container |
| RBAC | Kubernetes group `<team>-developers` gets `edit` in its own namespace only (cannot change Roles, quotas or limits) |
| Argo CD project | Source: this repo; destination: own namespace; no cluster-scoped objects; no ResourceQuota, LimitRange, Role, RoleBinding or NetworkPolicy |

To add a team, copy a team folder, replace the name everywhere, and push.

The groups are not yet mapped to IAM principals (that needs an EKS
access entry in the Terraform cluster layer, open item). RBAC is checked
by impersonation:
`kubectl auth can-i create deployments -n team-b --as=dev --as-group=team-a-developers`.

The root Application syncs automatically with **prune** (objects removed
from Git are deleted) and **self-heal** (manual changes in the cluster
are reverted). To undo a change, `git revert` the commit and push.

Check the status:

```bash
kubectl -n argocd get applications
```

## Releasing and rolling back an app

Example: `workloads/team-a/hello` (live at `https://hello.dev.domphil.org`
while dev is up).

1. Change the app in Git (for example the text in `index.html`), commit, push.
   Argo CD syncs within about three minutes (or click **Refresh**), and the
   Deployment rolls out with no dropped requests.
2. To roll back, revert the commit and push:

   ```bash
   git revert <commit> && git push
   ```

Apps that join the shared ALB must keep `scheme`, `ssl-redirect` and
`ssl-policy` identical to the Argo CD Ingress and must not set
`inbound-cidrs`; a conflict stops the Load Balancer Controller for every
Ingress in the group.
