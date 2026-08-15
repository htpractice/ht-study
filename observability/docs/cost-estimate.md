# Cost estimate — obs-on-eks (EKS Auto Mode multicluster)

Cost is not the primary constraint for this lab. Approximate AWS usage rates:

| Component | ~$/hr | Notes |
|-----------|-------|-------|
| EKS control plane | $0.10 | Per cluster |
| NAT gateway | $0.045 | Per VPC (single NAT enabled) |
| EKS Auto Mode compute | $0.05–0.20+ | Scales with pod load |
| NLB (NGINX) | $0.02–0.03 | Per cluster with ingress |

## Multicluster (default)

2 EKS Auto Mode clusters + 2 NAT + 2 NLB:

| Duration | ~Total |
|----------|--------|
| 1 hr | ~$0.35–0.50 |
| 5 hr | ~$1.75–2.50 |

## Single cluster (optional shortcut)

Apply only `terraform/environments/workload`, enable `enable_kube_prometheus_stack = true` in module call — run apps + obs stack on one cluster (~half the control-plane cost).

## Controls

- `enable_single_nat_gateway = true` (default)
- `cluster_enabled_log_types = []` (no CP logs unless you enable them)
- Destroy when done: `bash scripts/destroy-infra.sh`
