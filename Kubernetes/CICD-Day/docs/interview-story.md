# CI/CD + GitOps — interview cheat sheet

## Pipeline layers

| Layer | Tool | Owns |
|-------|------|------|
| CI | GitHub Actions | Build, test, scan, push artifact |
| Registry | ECR / Docker Hub | Immutable image |
| CD | Argo CD | Reconcile cluster ↔ Git |
| Package | Helm | Parameterized manifests |

**CI never applies to prod** — only updates Git; Argo deploys.

---

## Deployment strategies (name + one line)

| Strategy | Line |
|----------|------|
| Rolling | Default K8s; replace pods incrementally |
| Blue/green | Two envs; flip Service/ingress |
| Canary | Route small % traffic; metrics gate promote |
| Progressive delivery | Canary + automated analysis + rollback |

---

## GitOps rollback

1. **Preferred:** `git revert` the tag bump → Argo syncs old image  
2. **Argo UI:** History → rollback to revision  
3. **Not ideal:** `kubectl rollout undo` (drift if self-heal on)

---

## Terraform talking points

- Remote state + locking (S3 + DynamoDB)  
- `terraform plan` before apply; drift = plan ≠ reality  
- Modules for VPC/EKS reuse  
- **Destroy** lab resources — you did this same day

---

## Security (pipeline)

- OIDC to AWS > long-lived keys (upgrade path)  
- ECR scan on push  
- Secrets in GitHub Secrets, not in YAML  
- Branch protection on main/cka branch

---

## Your lab URLs to mention

- Repo path: `Kubernetes/CICD-Day/helm/order-api`  
- Workflow: `.github/workflows/order-api-cicd.yaml`  
- App source: `Logs&Monitoring-Day/APP`
