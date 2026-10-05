# AWS lab billing checklist — read before every deploy

**Lesson learned (Aug 2026):** Running EKS on **Kubernetes 1.33** after standard support ended (2026-07-29) billed **extended support** at **$0.60/cluster/hr** instead of **$0.10** — **6×** control-plane cost. Two clusters ≈ **$1.20/hr** CP alone. This was not obvious from the old cost estimate.

Use this checklist **before** `bash scripts/deploy-infra.sh` and **after** any long-running lab.

---

## 1. EKS Kubernetes version (highest impact)

| Tier | $/cluster/hr | When |
|------|----------------|------|
| Standard support | **$0.10** | First ~14 months after EKS releases that minor version |
| Extended support | **$0.60** | Next ~12 months after standard ends — **automatic**, no opt-in required |

**Before deploy:**

1. Open [EKS Kubernetes versions](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html) — check **End of standard support** for your `kubernetes_version` in `obs.tfvars` / `workload.tfvars`.
2. If today is **after** that date → you pay extended support until you upgrade.
3. Prefer a version still in **standard support** (e.g. bump `kubernetes_version` in both tfvars files).

```bash
# After cluster exists — confirm version
aws eks describe-cluster --name retail-obs --region us-west-2 --query 'cluster.version'
aws eks describe-cluster --name retail-workload --region us-west-2 --query 'cluster.version'
```

**Rule of thumb:** Never pin a minor version in tfvars without checking the support calendar for your lab dates.

---

## 2. Multicluster multiplier

This lab runs **two** EKS clusters (obs + workload). Most hourly costs are **×2**:

| Component | Per cluster | This lab (×2) |
|-----------|-------------|---------------|
| EKS control plane | $0.10 standard / $0.60 extended | Double |
| NAT gateway | ~$0.045/hr | ~$0.09/hr |
| NLB (ingress) | ~$0.02–0.03/hr | ~$0.04–0.06/hr |

See [cost-estimate.md](./cost-estimate.md) for full breakdown.

---

## 3. Always destroy when done

```bash
bash scripts/destroy-infra.sh
aws eks list-clusters --region us-west-2   # must be []
```

S3 tfstate buckets cost pennies; **running clusters do not**.

---

## 4. Monthly sanity check

```bash
aws eks list-clusters --region us-west-2
aws ce get-cost-and-usage \
  --time-period Start=$(date -v-30d +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --filter '{"Dimensions":{"Key":"SERVICE","Values":["Amazon Elastic Container Service for Kubernetes"]}}'
```

In **Cost Explorer**, filter usage type for **ExtendedSupport** if the bill looks high.

---

## 5. Other common lab leaks (quick scan)

| Resource | Check |
|----------|--------|
| Orphaned EBS volumes | EC2 → Volumes → available, unattached |
| NAT gateways | VPC → NAT gateways in lab VPCs |
| Load balancers | EC2 → Load balancers |
| EKS Auto Mode compute | Scales with pods — scale down or destroy cluster |

---

## Pre-deploy one-liner (copy to sticky note)

> **Version in standard support? ×2 clusters? destroy-infra when done?**

Related: [LAB-SPEC.md](./LAB-SPEC.md) · [cost-estimate.md](./cost-estimate.md)
