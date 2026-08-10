# AWS one-day E2E — Terraform → EKS → Argo CD → GitHub Actions → Helm

**Goal:** Full pipeline you can screenshot and describe in 90 seconds, then **destroy same day**.

**App:** `order-api` (reuse `Logs&Monitoring-Day/APP`)  
**Stack:** Terraform (EKS + ECR) · Helm chart · Argo CD · GitHub Actions

**Cost:** ~₹500–1.5k for ~10–12 hours (EKS + 2× spot `t3.small`, LB). **Set AWS Budget alert first.**

---

## Layout

```
CICD-Day/
├── terraform/          # EKS + ECR
├── helm/order-api/     # GitOps source of truth (image tag bumped by CI)
├── argocd/             # Application manifest
└── docs/               # you are here

.github/workflows/order-api-cicd.yaml   # build → ECR → commit values.yaml
```

---

## Phase 0 — Before you start (15 min)

### AWS

- [ ] AWS CLI configured (`aws sts get-caller-identity`)
- [ ] Budget alert at ₹500 / $10
- [ ] Region: `ap-south-1` (or edit `terraform.tfvars`)

### GitHub repo secrets

Settings → Secrets → Actions:

| Secret | Value |
|--------|--------|
| `AWS_ACCESS_KEY_ID` | IAM user with ECR push + EKS describe |
| `AWS_SECRET_ACCESS_KEY` | |

IAM minimum for lab: `AmazonEC2ContainerRegistryPowerUser` + EKS cluster access (or admin for one day).

### Screenshot folder

```bash
mkdir -p ~/crowdstrike-prep/aws-e2e-$(date +%Y%m%d)
```

---

## Phase 1 — Terraform: EKS + ECR (~45–60 min)

```bash
cd ht-study/Kubernetes/CICD-Day/terraform

cp terraform.tfvars.example terraform.tfvars
# edit region/cluster_name if needed

terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Save outputs:

```bash
terraform output -json | tee ~/crowdstrike-prep/aws-e2e-*/terraform-outputs.json
export CLUSTER=$(terraform output -raw cluster_name)
export ECR_URL=$(terraform output -raw ecr_repository_url)
aws eks update-kubeconfig --name "$CLUSTER" --region ap-south-1
kubectl get nodes
```

**Screenshot:** nodes Ready · EKS console · ECR repo created

### Update Helm values with ECR URL

```bash
cd ../helm/order-api
# Set image.repository to $ECR_URL in values.yaml (keep tag v1 for now)
```

Commit & push when ready (or after Phase 4).

---

## Phase 2 — Install Argo CD (~15 min)

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl wait -n argocd --for=condition=available deployment/argocd-server --timeout=300s

# CLI (optional)
brew install argocd

# Initial admin password
argocd admin initial-password -n argocd

# Port-forward UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# https://localhost:8080  user: admin
```

**Screenshot:** Argo CD login / empty Applications

---

## Phase 3 — Register Git repo + Application

If repo is **public**, apply Application directly:

```bash
kubectl apply -f ../../argocd/application-order-api.yaml
```

If **private**, add repo in Argo UI: Settings → Repositories → Connect GitHub.

Watch sync:

```bash
kubectl get applications -n argocd
argocd app get order-api
kubectl get pods,svc -n order-api
```

**First sync needs an image in ECR** — either:

```bash
# Manual first push (before Actions wired)
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin <account>.dkr.ecr.ap-south-1.amazonaws.com
docker build -t ${ECR_URL}:v1 ../../Logs\&Monitoring-Day/APP
docker push ${ECR_URL}:v1
```

Then set `values.yaml` tag `v1`, push Git, Argo syncs.

**Screenshot:** Argo app Synced/Healthy · pods Running

---

## Phase 4 — Expose app + verify

```bash
kubectl get svc -n order-api
# Wait for EXTERNAL-IP (Classic/NLB)
curl -s http://<EXTERNAL-IP>/health
curl -X POST http://<EXTERNAL-IP>/order -H "Content-Type: application/json" -d '{"product":"phone"}'
```

**Screenshot:** LoadBalancer URL · browser/curl health · Argo + K8s side by side

---

## Phase 5 — GitHub Actions → GitOps loop (~30 min)

1. Ensure secrets are set (Phase 0)
2. Push a small change to `APP/app.py` (e.g. log message) OR run workflow manually:

   GitHub → Actions → **order-api CI/CD** → Run workflow

3. Watch pipeline: build → ECR push → commit `values.yaml` with new tag
4. Argo CD auto-syncs (30–90s) or click Sync in UI
5. Verify new image:

```bash
kubectl get deploy -n order-api -o jsonpath='{.items[0].spec.template.spec.containers[0].image}'
kubectl rollout status deployment/order-api -n order-api
```

**Screenshot:** GitHub Actions green · Git commit from bot · Argo revision updated · new image running

---

## Phase 6 — Rollback drill (5 min — interview gold)

```bash
git revert HEAD   # reverts CI tag bump
git push
# Argo syncs previous tag
```

Or in Argo UI: **History and rollback** → previous revision.

**Screenshot:** Rollback in Argo history

---

## Phase 7 — Teardown (same day — mandatory)

```bash
# Delete Argo app first (optional — terraform destroy will wipe cluster)
kubectl delete application order-api -n argocd --wait=false

cd ht-study/Kubernetes/CICD-Day/terraform
terraform destroy

# Verify AWS console: no EKS, no LB, no EBS orphans
```

**Screenshot:** empty EKS / billing

---

## Interview 90-second story

> "I stood up EKS with Terraform — VPC, spot node group, ECR. The app ships as a Helm chart in Git. GitHub Actions builds the container, pushes to ECR, and commits the image tag to values.yaml — CI never kubectl-applies. Argo CD watches the repo and syncs to the cluster with self-heal. Rollback is revert the Git commit or Argo history. I destroyed the stack same day; locally I repeat the GitOps loop on kind."

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Nodes NotReady | Wait 5 min; check `kubectl describe node` |
| ImagePullBackOff | ECR URL/tag wrong; run manual push; check node IAM ECR read |
| Argo OutOfSync loop | Check helm values YAML valid; `argocd app diff order-api` |
| Actions push denied | `contents: write` permission; branch protection bypass for bot |
| LB pending forever | Check subnet tags `kubernetes.io/role/elb`; public subnets |

---

## After today

Weekend/kind path: [kind-gitops.md](kind-gitops.md) — same Helm + Argo, no AWS cost.
