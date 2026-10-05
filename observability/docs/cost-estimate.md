# Cost estimate — obs-on-eks (EKS Auto Mode multicluster)

> **Read first:** [AWS-BILLING-CHECKLIST.md](./AWS-BILLING-CHECKLIST.md) — especially **EKS extended support** ($0.60 vs $0.10 per cluster per hour).

Approximate AWS usage rates (us-west-2):

| Component | ~$/hr | Notes |
|-----------|-------|-------|
| EKS control plane (standard) | **$0.10** | Per cluster — version in **standard** support |
| EKS control plane (extended) | **$0.60** | Per cluster — version past standard support end date |
| NAT gateway | $0.045 | Per VPC (single NAT enabled) |
| EKS Auto Mode compute | $0.05–0.20+ | Scales with pod load |
| NLB (NGINX) | $0.02–0.03 | Per cluster with ingress |

## Multicluster (default) — standard support pricing

2 EKS clusters + 2 NAT + 2 NLB, **both on standard support** ($0.10/cluster/hr):

| Duration | ~Total |
|----------|--------|
| 1 hr | ~$0.35–0.50 |
| 5 hr | ~$1.75–2.50 |
| 8 hr | ~$4–5 |

## Extended support warning

If `kubernetes_version` in tfvars is past **End of standard support** (see [AWS version calendar](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html)):

- Control plane alone: **2 × $0.60 = $1.20/hr** (vs $0.20/hr standard)
- **~$8 extra** on control plane for an 8h lab vs standard pricing
- Bill line item: **Amazon EKS extended support usage**

**Always bump to a supported minor version before deploy** (checklist in AWS-BILLING-CHECKLIST.md).

## Single cluster (optional shortcut)

Apply only `terraform/environments/workload`, enable `enable_kube_prometheus_stack = true` in module call — run apps + obs stack on one cluster (~half the control-plane cost).

## Controls

- `enable_single_nat_gateway = true` (default)
- `cluster_enabled_log_types = []` (no CP logs unless you enable them)
- Destroy when done: `bash scripts/destroy-infra.sh`
- Verify empty: `aws eks list-clusters --region us-west-2`
