# Day 2 — Full EKS + CI/CD (after kubeadm Day 1)

**Prerequisite:** Completed [e2e-day1.md](../../KubeADM-Day/docs/e2e-day1.md) (kubeadm concepts understood).

**Goal:** Same GitOps loop on managed EKS — Terraform, ECR, GitHub Actions, Argo CD, destroy.

**Time:** ~4–5 hours.

---

## What Day 1 vs Day 2 covers

| Concept | kubeadm Day 1 | EKS Day 2 |
|---------|-----------------|-----------|
| Cluster lifecycle | kubeadm init/join/upgrade | EKS API + node groups |
| CNI | Flannel (self-managed) | AWS VPC CNI (default) |
| LoadBalancer | NodePort | AWS NLB/CLB via Service type LoadBalancer |
| GitOps | Argo CD + Helm | Same Application, `values-aws.yaml` |
| CI | Manual tag bump / optional | GitHub Actions → ECR → git commit |
| IaC | EC2 Terraform | EKS + VPC Terraform |
| Monitoring | Prometheus Helm on cluster | Same stack + CloudWatch optional |

---

## Phase 1 — Terraform EKS (~45 min)

Full runbook: [aws-e2e-afternoon.md](aws-e2e-afternoon.md)

```bash
cd Kubernetes/CICD-Day/terraform
cp terraform.tfvars.example terraform.tfvars   # edit region/account
terraform init && terraform apply
terraform output   # cluster_name, ecr_repository_url, kubectl command
```

Configure kubectl:

```bash
aws eks update-kubeconfig --region <region> --name cicd-day-eks
kubectl get nodes
```

---

## Phase 2 — ECR + build image (~30 min)

```bash
ECR_URL=$(terraform output -raw ecr_repository_url)
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin ${ECR_URL%/*}

docker build -t ${ECR_URL}:v1 Kubernetes/Logs&Monitoring-Day/APP
docker push ${ECR_URL}:v1
```

Copy and edit values:

```bash
cp helm/order-api/values-aws.example.yaml helm/order-api/values-aws.yaml
# set repository + tag to ECR URL
git add helm/order-api/values-aws.yaml && git commit -m "eks: order-api v1" && git push
```

---

## Phase 3 — Argo CD on EKS (~30 min)

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Patch Application to use values-aws.yaml (or create application-order-api-eks.yaml)
kubectl apply -f argocd/application-order-api.yaml
kubectl get svc -n order-api   # EXTERNAL-IP from AWS LB
```

---

## Phase 4 — GitHub Actions CI (~30 min)

Workflow: `.github/workflows/order-api-cicd.yaml`

Secrets in repo: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`

Push to `cka-2026-study` → build → ECR push → patch `values.yaml` tag → Argo syncs.

---

## Phase 5 — EKS Day-2 topics (interview depth)

Know these even if you don't lab all of them today:

### IRSA (IAM Roles for Service Accounts)
- OIDC provider on cluster → trust policy on IAM role → annotate K8s SA
- "Pods get AWS permissions without node-wide credentials"

### Cluster Autoscaler
- Scales node group when pods are Pending (resource requests)
- Tags on ASG: `k8s.io/cluster-autoscaler/enabled`, cluster name

### AWS Load Balancer Controller
- Ingress / Service type LoadBalancer → ALB/NLB
- Replaces in-tree cloud provider (deprecated)

### Add-on upgrades
- `eks update-cluster-version` one minor at a time (like kubeadm)
- Managed add-ons: vpc-cni, coredns, kube-proxy via EKS console/API

### Node rotation
- New node group at target K8s version → cordon/drain old → delete old NG

### Backup
- Velero + S3 for cluster resources; RDS/EKS are separate

### Cost
- Spot node groups (already in terraform), right-size, cluster autoscaler, tear down labs

### Security
- NetworkPolicy + security groups, secrets in AWS Secrets Manager / External Secrets, image scan in pipeline

---

## Phase 6 — Monitoring on EKS (~30 min)

Same Helm stack as Day 1:

```bash
helm install prometheus prometheus-community/prometheus \
  -n observability --create-namespace \
  -f ../Logs&Monitoring-Day/manifests/prometheus-values.yaml
```

order-api already has prometheus annotations in Helm chart.

---

## Teardown

```bash
cd Kubernetes/CICD-Day/terraform && terraform destroy
# Delete ECR images if needed
```

---

## Interview story (EKS)

> "Day 1 I ran kubeadm on EC2 — full control of CNI, upgrades, drain. Day 2 same app on EKS: Terraform for cluster + ECR, GitHub Actions builds and bumps Helm tag, Argo CD syncs. LoadBalancer via AWS, IRSA for pod IAM, cluster autoscaler for scale. Upgrade path is managed control plane + node group rotation."
