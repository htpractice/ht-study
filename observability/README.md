# obs-on-eks — E2E Observability on EKS Auto Mode

**Branch:** `obs-on-eks` · **Region:** `us-west-2`

Multicluster observability lab:

| Cluster | Role | Telemetry |
|---------|------|-----------|
| **workload** | ArgoCD → `htpractice/retail-store-sample-app` | ADOT scrapes `/metrics` + OTLP → obs |
| **obs** | Central monitoring | Prometheus (remote_write receiver), Grafana, Loki, Jaeger |

## Three pillars (all in Terraform)

| Signal | Agent (both clusters) | Central store (obs) | Cross-cluster |
|--------|----------------------|---------------------|---------------|
| **Metrics** | ADOT (prometheus receiver → remote_write) | Prometheus | Internal NLB over VPC peering |
| **Logs** | Promtail DaemonSet (per node) | Loki | Internal NLB over VPC peering |
| **Traces** | ADOT (OTLP receiver → export) | Jaeger | Internal NLB :4317 over peering |

## Deploy (order matters: obs → workload → peering)

```bash
cd ht-study/observability

# One-time: isolated state buckets (separate from KubeADM lab)
bash scripts/bootstrap-state.sh

bash scripts/deploy-infra.sh
bash scripts/verify-telemetry.sh
```

## Teardown

```bash
bash scripts/destroy-infra.sh
```

## Layout

```
observability/terraform/modules/eks-cluster/
  addons.tf           # NGINX, kube-prometheus-stack, ADOT EKS add-on
  obs-backend.tf      # Loki + Jaeger internal NLBs (obs only)
  telemetry-adot.tf   # OpenTelemetryCollector CR (both clusters)
  telemetry-logs.tf   # Promtail DaemonSet (both clusters)
  argocd.tf           # workload only
```

See [docs/LAB-SPEC.md](docs/LAB-SPEC.md) for verification queries and interview talking points.
