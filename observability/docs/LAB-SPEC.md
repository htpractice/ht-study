# obs-on-eks — Lab Spec (EKS Auto Mode)

Terraform is adapted from [retail-store-sample-app](../../../retail-store-sample-app/terraform/) (fork: `htpractice/retail-store-sample-app`).

**Runbook:** [TROUBLESHOOTING-REF.md](./TROUBLESHOOTING-REF.md) — commands, PromQL/LogQL, incidents, Grafana panels.  
**Practice plan:** [PRACTICE-ROADMAP.md](./PRACTICE-ROADMAP.md) — PromQL levels, SLO dashboard, 70–80% checklist.

## Architecture

```
workload VPC 10.0.0.0/16                    obs VPC 10.1.0.0/16
├── EKS Auto Mode (retail-workload-*)       ├── EKS Auto Mode (retail-obs-*)
├── NGINX NLB + cert-manager                ├── NGINX NLB
├── ArgoCD → retail-store apps              ├── kube-prometheus-stack (Terraform)
├── 5 microservices (prometheus annotations)├── + Loki/Jaeger (Helm script)
└── metrics on /metrics, /actuator/prom     └── scrapes workload over VPC peering
         └──── terraform/environments/peering ────┘
```

---

## Phase 0 — Push fork to GitHub (before workload apply)

ArgoCD pulls from GitHub, not local disk:

```bash
cd /Users/thawarh/Documents/HT-Study/retail-store-sample-app
git add argocd/ src/*/chart/values-obs-on-eks.yaml
git commit -m "obs-on-eks: htpractice repo, OTel instrumentation, values overlay"
git push origin main
```

Fork: https://github.com/htpractice/retail-store-sample-app

---

## Phase 1 — Terraform (obs → peering → workload)

```bash
cd ht-study/observability
bash scripts/deploy-infra.sh
bash scripts/verify-telemetry.sh
```

**Obs cluster** installs:
- kube-prometheus-stack (remote write receiver + internal NLB)
- Loki + Jaeger (internal NLBs for cross-VPC push/scrape)
- ADOT + Promtail (local cluster telemetry)

**Workload cluster** installs:
- ArgoCD + retail-store apps
- ADOT → remote_write to obs Prometheus (URL from obs terraform state)
- Promtail → push logs to obs Loki
- **kube-state-metrics** + cAdvisor scrape via ADOT → infra metrics for default Grafana dashboards

**Gates:**
```bash
kubectl --context obs-eks get pods -n monitoring
kubectl --context obs-eks get pods -n observability
kubectl --context workload-eks get pods -n opentelemetry-operator-system
terraform -chdir=terraform/environments/obs output telemetry_endpoints
```

---

## Phase 2 — Verify metrics (ADOT → Prometheus → Grafana)

```bash
kubectl --context obs-eks port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Query: up{cluster="retail-workload"}
```

Generate traffic via retail-store UI, then check Grafana:
```bash
kubectl --context obs-eks port-forward -n monitoring svc/prometheus-grafana 3000:80
# admin password: cka-lab
```

---

## Phase 3 — Traces (enabled in fork)

`values-obs-on-eks.yaml` enables OTel on **ui, catalog, checkout** with `Instrumentation` CR → ADOT → Jaeger on obs.

Metrics on all services via existing `prometheus.io/*` annotations (scraped by ADOT).

---

## Phase 4 — Verify logs (Promtail → Loki)

```bash
kubectl --context obs-eks port-forward -n monitoring svc/prometheus-grafana 3000:80
# Explore → Loki → {cluster="retail-workload"}
```

---

## Useful commands

```bash
# ArgoCD UI (use http, not https — server runs with --insecure)
kubectl --context workload-eks port-forward svc/argocd-server -n argocd 8080:443
# http://localhost:8080  user: admin  password: see argocd-initial-admin-secret

# Grafana (obs)
kubectl --context obs-eks get secret -n monitoring prometheus-grafana -o jsonpath='{.data.admin-password}' | base64 -d
kubectl --context obs-eks port-forward -n monitoring svc/prometheus-grafana 3000:80

# Store URL
terraform -chdir=terraform/environments/workload output retail_store_url
```

---

## Fixes baked in (Aug 2026 session — fresh deploy should be zero-touch)

| Area | Fix | Where |
|------|-----|--------|
| Retail fork | `htpractice/retail-store-sample-app` on `main`, `values-obs-on-eks.yaml`, OTel/trace fixes | fork (already pushed) |
| ADOT collector | SA + ClusterRole + RBAC before `OpenTelemetryCollector` CR | `terraform/modules/eks-cluster/telemetry-adot-rbac.tf` |
| Loki | `loki-stack` chart (not `loki` v6), `useTestSchema` not needed | `helm-values/loki-stack-obs.yaml` |
| Jaeger | Split Service + Deployment in TF (`kubectl_manifest` is one doc per block); Grafana DS URL `jaeger` not `jaeger-query` | `obs-backend.tf`, `manifests/jaeger.yaml`, `helm-values/kube-prometheus-obs.yaml` |
| Helm provider | v3 syntax `kubernetes = { ... }` | `terraform/modules/eks-cluster/versions.tf` |
| Namespace | `kubernetes_namespace_v1` for observability | `obs-backend.tf` |
| ArgoCD apps | `imagePullSecrets: []` in overlay (public ECR) | fork `values-obs-on-eks.yaml` |
| Infra metrics | kube-state-metrics on workload + ADOT cAdvisor/KSM scrape → remote_write | `telemetry-kube-state-metrics.tf`, `adot-collector.yaml.tpl` |

**Deploy order:** obs → workload → peering (`scripts/deploy-infra.sh`).

**Post-deploy gates (all must pass before UI lab):**
```bash
terraform -chdir=terraform/environments/obs output telemetry_endpoints   # NLB hostnames, not empty
kubectl --context workload-eks get pods -n opentelemetry-operator-system  # adot-collector-collector Running
kubectl --context obs-eks get pods,endpoints -n observability -l app=jaeger  # pod + endpoints
kubectl --context workload-eks get applications -n argocd                   # all Synced
```

**Verify all three signals:**
```promql
# App metrics
up{namespace="retail-store", app_kubernetes_io_instance="retail-store-ui"}
http_server_requests_seconds_count{app_kubernetes_io_instance="retail-store-ui"}

# Infra metrics (Grafana Pod Compute dashboard / namespace dropdown)
kube_pod_info{namespace="retail-store", cluster="retail-workload"}
container_cpu_usage_seconds_total{namespace="retail-store", cluster="retail-workload"}
rate(container_cpu_usage_seconds_total{namespace="retail-store", pod=~"retail-store-ui.*"}[5m])
```
```logql
{cluster="retail-workload"}                            # Loki
```
Jaeger UI → service `catalog` after store traffic.

**Grafana:** http://localhost:3000 — `admin` / `cka-lab`

---

## Teardown

```bash
bash scripts/destroy-infra.sh
```
