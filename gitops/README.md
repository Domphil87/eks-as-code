# GitOps

Everything in this folder is deployed by **Argo CD**, not Terraform
([ADR 0002](../docs/adr/0002-terraform-vs-argocd.md)). Commit and push to
`main`; Argo CD applies the change within about three minutes.

```text
gitops/
└── apps/              ← watched by the root Application ("App of Apps")
    └── smoke-test.yaml   ConfigMap proving the loop works (5b)
```

The root Application syncs automatically with **prune** (objects removed
from Git are deleted) and **self-heal** (manual changes in the cluster
are reverted). To undo a change, `git revert` the commit and push.

Check the status:

```bash
kubectl -n argocd get applications
```
