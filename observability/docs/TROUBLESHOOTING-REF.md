# obs-on-eks — Troubleshooting & Commands Reference

Personal runbook from the Aug 2026 lab sessions. Complements [LAB-SPEC.md](./LAB-SPEC.md) (deploy/teardown). This doc is for **day-2 ops, debugging, Grafana, and interview prep**.

**Contexts:** `obs-eks` (central observability) · `workload-eks` (retail-store apps)

---

## Quick access

| What | Command / URL |
|------|----------------|
| **Grafana** | `kubectl --context obs-eks port-forward -n monitoring svc/prometheus-grafana 3000:80` → http://localhost:3000 (`admin` / `cka-lab`) |
| **Prometheus UI** | `kubectl --context obs-eks port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090` |
| **ArgoCD** | `kubectl --context workload-eks port-forward svc/argocd-server -n argocd 8080:443` → **http**://localhost:8080 (not https) |
| **Store UI** | Ingress NLB (preferred): `kubectl --context workload-eks get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='http://{.status.loadBalancer.ingress[0].hostname}{"\n"}'` |
| **Store UI (port-forward)** | `kubectl --context workload-eks port-forward -n retail-store svc/retail-store-ui 8888:80` → http://localhost:8888 |
| **Telemetry NLB endpoints** | `terraform -chdir=ht-study/observability/terraform/environments/obs output telemetry_endpoints` |
| **Verify pipeline** | `bash ht-study/observability/scripts/verify-telemetry.sh` |
| **Destroy (cost)** | `bash ht-study/observability/scripts/destroy-infra.sh` |

---

## Signal paths (what to check when X is broken)

```
METRICS (pull + push)
  retail-store pod :8080/actuator/prometheus  (or /metrics for Go services)
       ↓ ADOT scrape (workload)
  ADOT collector → remote_write → obs Prometheus NLB :9090
       ↓ query in Grafana (Prometheus datasource on obs)

LOGS (push)
  workload pod logs → Promtail → obs Loki NLB :3100
       ↓ Grafana Explore → Loki → {cluster="retail-workload"}

TRACES (push)
  app OTLP → ADOT :4318 → obs Jaeger NLB :4317
       ↓ Grafana Explore → Jaeger (or Jaeger UI via DS)
```

**Interview line:** Logs/traces are **push**. App metrics are **pull** (ADOT scrape) then **push** (remote_write). Infra metrics (KSM + cAdvisor) same ADOT path on workload.

---

## kubectl health checks

```bash
# Obs stack
kubectl --context obs-eks get pods -n monitoring
kubectl --context obs-eks get pods -n observability
kubectl --context obs-eks get pods -n observability -l app=jaeger
kubectl --context obs-eks get endpoints -n observability jaeger

# Workload apps + telemetry
kubectl --context workload-eks get pods -n retail-store
kubectl --context workload-eks get pods -n monitoring                    # kube-state-metrics
kubectl --context workload-eks get pods -n opentelemetry-operator-system
kubectl --context workload-eks get applications -n argocd
kubectl --context workload-eks get instrumentation -n retail-store

# Scrape annotations on retail pods
kubectl --context workload-eks get pods -n retail-store \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.annotations.prometheus\.io/scrape}{"\t"}{.metadata.annotations.prometheus\.io/port}{"\t"}{.metadata.annotations.prometheus\.io/path}{"\n"}{end}'

# ADOT collector logs (scrape / remote_write errors)
kubectl --context workload-eks logs -n opentelemetry-operator-system \
  -l app.kubernetes.io/name=adot-collector-collector --tail=50
```

---

## PromQL cheat sheet

Spring Boot uses **`http_server_requests_seconds_count`**, not `http_requests_total`.

### App health

```promql
# UI pod scraped?
up{namespace="retail-store", app_kubernetes_io_instance="retail-store-ui"}

# All retail services
up{namespace="retail-store"}

# Raw request counter (explore labels: method, uri, status)
http_server_requests_seconds_count{app_kubernetes_io_instance="retail-store-ui"}
```

### Custom dashboard — Panel 1: total UI request rate

```promql
sum(
  rate(http_server_requests_seconds_count{
    app_kubernetes_io_instance="retail-store-ui",
    uri!~"/actuator.*"
  }[5m])
)
```

Unit: **requests/sec**. Exclude `/actuator.*` to drop health-check noise.

### Requests in last hour (stat panel)

```promql
sum(
  increase(http_server_requests_seconds_count{
    app_kubernetes_io_instance="retail-store-ui",
    uri!~"/actuator.*"
  }[1h])
)
```

### Infra (default K8s dashboards — Pod Compute)

```promql
kube_pod_info{namespace="retail-store", cluster="retail-workload"}
container_cpu_usage_seconds_total{namespace="retail-store"}
rate(container_cpu_usage_seconds_total{namespace="retail-store", pod=~"retail-store-ui.*"}[5m])
```

### Label gotchas

| You might search | Use instead |
|------------------|-------------|
| `job="retail-store-ui"` | `job="kubernetes-pods"` |
| `http_requests_total` | `http_server_requests_seconds_count` (Java) or `/metrics` counters (Go) |
| `up{cluster="retail-workload"}` | Works after `resource_to_telemetry_conversion`; else use `namespace="retail-store"` |
| Prometheus **Targets** page | Shows **obs-local** scrapes only; workload targets scraped by ADOT |

---

## LogQL cheat sheet

```logql
# All workload logs
{cluster="retail-workload"}

# UI logs only
{cluster="retail-workload", namespace="retail-store", pod=~"retail-store-ui.*"}

# Errors
{cluster="retail-workload"} |= "error"
{cluster="retail-workload"} |~ "5[0-9]{2}"   # 5xx-ish

# Around an incident time (adjust timestamp)
{cluster="retail-workload", app_kubernetes_io_instance="retail-store-ui"} |= "GET"
```

---

## Jaeger / trace investigation

```bash
# Jaeger must have pod + endpoints
kubectl --context obs-eks get pods,endpoints -n observability -l app=jaeger
```

**Grafana:** Explore → Jaeger datasource → Service: `retail-store-ui` (or `catalog`) → Find Traces.

**Example incident workflow (from lab):**

1. **Symptom:** Browser slow / 500 on homepage (~18s).
2. **Loki:** `{cluster="retail-workload"}` → 500 on GET at ~11:24:30.
3. **Jaeger:** Service `retail-store-ui`, operation GET, trace e.g. `b9d7ffb2015ca4939acd8437feae1e2b`.
4. **Spans:** Slow child `GET catalog/products/{id}` (~6s); sibling hit **OkHttp ~10s timeout** → `Socket closed`.
5. **Conclusion:** Downstream catalog latency / cold start, not ingress or obs stack.

---

## Troubleshooting scenarios

### Jaeger pod missing (Service exists, no endpoints)

**Symptom:** `kubectl get pods -l app=jaeger` → empty; Grafana Jaeger 502.

**Cause:** `kubectl_manifest` with multi-doc YAML only applied the Service, not Deployment.

**Fix (immediate):**
```bash
kubectl --context obs-eks apply -f ht-study/observability/manifests/jaeger.yaml
kubectl --context obs-eks get pods,endpoints -n observability -l app=jaeger
```

**Fix (IaC):** `obs-backend.tf` splits `jaeger_service` + `jaeger_deployment`.

---

### Grafana Jaeger datasource 502

**Cause:** Datasource URL pointed at `jaeger-query` instead of `jaeger`.

**Correct URL:** `http://jaeger.observability.svc.cluster.local:16686`

---

### Store UI port-forward not working

**Use ingress NLB instead** (ClusterIP service, UI exposed via nginx):

```bash
kubectl --context workload-eks get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='http://{.status.loadBalancer.ingress[0].hostname}{"\n"}'
```

Port-forward fallback: `8888:80` (not 8080), context `workload-eks`.

---

### No retail-store metrics in Prometheus

1. Confirm query on **obs** Prometheus (not workload).
2. Use `app_kubernetes_io_instance="retail-store-ui"`, not `http_requests_total`.
3. Check ADOT: `kubectl --context workload-eks get pods -n opentelemetry-operator-system`
4. ADOT logs for `prometheusremotewrite` / `Failed to scrape`.

**Remote write test from workload:**
```bash
PROM_LB=$(terraform -chdir=ht-study/observability/terraform/environments/obs output -raw telemetry_endpoints | jq -r .prometheus_remote_write 2>/dev/null || echo "<prom-nlb>:9090")
# curl -sS -o /dev/null -w "%{http_code}" -X POST "http://${PROM_LB}/api/v1/write" ...
```

---

### Default Grafana dashboards missing `retail-store` namespace

**Cause:** Dashboards need `kube_pod_info` + `container_*` from **kube-state-metrics** and **cAdvisor**, not just app metrics.

**Fix (in lab):** `enable_infra_metrics_export = true` on workload → KSM helm + ADOT scrape jobs `kube-state-metrics` + `kubernetes-nodes-cadvisor` with `honor_labels: true` on KSM.

**Verify:**
```bash
kubectl --context obs-eks exec -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=count(kube_pod_info{namespace="retail-store"})'
```

---

### ADOT collector FailedCreate (missing SA)

**Fix:** `telemetry-adot-rbac.tf` — ServiceAccount + ClusterRole before OpenTelemetryCollector CR.

---

### Checkout / catalog slow on first page load

**Typical trace pattern:** UI → multiple `catalog/products/{id}` spans; one ~6s, one ~10s + `java.net.SocketException: Socket closed` (OkHttp default read timeout).

**Next steps:** Catalog pod logs, `up{namespace="retail-store"}`, retry after warm-up; not an observability pipeline bug.

---

## Prometheus queries from CLI (inside obs pod)

### Discover available metric names (before building Grafana panels)

List all metric names, filtered for HTTP / request-related series:

```bash
kubectl --context obs-eks exec -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/label/__name__/values' \
  | tr ',' '\n' | rg -i 'http.*request|http_server' | head -25
```

Inspect labels + sample values for the UI app (confirms Spring uses `http_server_requests_seconds_count`, not `http_requests_total`):

```bash
kubectl --context obs-eks exec -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=http_server_requests_seconds_count{app_kubernetes_io_instance="retail-store-ui"}'
```

List all metric names containing `http_server` (narrower filter):

```bash
kubectl --context obs-eks exec -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/label/__name__/values' | tr ',' '\n' | rg 'http_server'
```

See which label dimensions exist on a metric (method, uri, status, etc.):

```bash
kubectl --context obs-eks exec -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/series?match[]=http_server_requests_seconds_count{app_kubernetes_io_instance="retail-store-ui"}&limit=10'
```

### General PromQL from CLI

```bash
kubectl --context obs-eks exec -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=up{namespace="retail-store"}'
```

**Tip:** Pipe through `jq` for readability: `... | jq .`

### Three different “metrics” endpoints (common confusion)

| URL | What it is | Will you see `http_server_requests_seconds_*`? |
|-----|------------|-----------------------------------------------|
| `http://localhost:9090/metrics` | **Prometheus process** self-metrics (`go_*`, `prometheus_*`) | **No** — not app data |
| `http://localhost:9090/api/v1/query?query=...` | **Prometheus query API** — stored scraped metrics | **Yes** — use PromQL |
| `http://<ui-pod>:8080/actuator/prometheus` | **Spring Boot app** raw exposition (Java services) | **Yes** — source before ADOT scrape |

Raw UI metrics from inside the cluster:

```bash
kubectl --context workload-eks run curl-ui --rm -i --restart=Never \
  --image=curlimages/curl:8.5.0 --timeout=30s -- \
  curl -sS http://retail-store-ui.retail-store.svc:80/actuator/prometheus \
  | rg 'http_server_requests_seconds'
```

Go services (catalog, checkout) use port **8080** path **`/metrics`** instead of `/actuator/prometheus`.

---

## Terraform re-apply (after code fixes)

```bash
# Workload only (KSM + ADOT template)
terraform -chdir=ht-study/observability/terraform/environments/workload apply

# Obs only (Jaeger split, etc.)
terraform -chdir=ht-study/observability/terraform/environments/obs apply
```

**Deploy order:** obs → workload → peering (`scripts/deploy-infra.sh`).

**Destroy order:** workload → peering → obs (`scripts/destroy-infra.sh`).

---

## Interview sound bites (360 prep)

- **Three pillars:** Metrics = symptoms/trends; Logs = context; Traces = causality across services.
- **Multi-cluster:** Central obs on dedicated cluster; workload pushes/pulls over VPC peering + internal NLBs.
- **ADOT:** Operator deploys collector from CR; you own SA/RBAC and scrape config.
- **Service with no endpoints:** Kubernetes Service exists but no pods match selector → nothing to route to (Jaeger lesson).
- **Pull vs push:** Prometheus scrape = pull; Loki/Jaeger/remote_write = push.
- **Micrometer naming:** `http_server_requests_seconds_count` + `rate()` for RPS; histogram `_bucket` for latency percentiles.

---

## Custom Grafana dashboard

**Backup (exported v13):**
- `dashboards/sli-dashboard.json` — full dashboard
- `dashboards/sli-dashboard-export.json` — API wrapper (meta + dashboard)
- `dashboards/library-panels/*-full.json` — library panels with UIDs (import these **first**)

**Re-import next lab** (after `port-forward` Grafana on :3000):

```bash
chmod +x dashboards/import-grafana.sh
./dashboards/import-grafana.sh
```

Or manual: Grafana → Dashboards → Import → `sli-dashboard.json` (library panels must exist or panels show broken refs).

| Panel | Title | Query |
|-------|-------|-------|
| 1 | UI total request rate | `sum(rate(http_server_requests_seconds_count{app_kubernetes_io_instance="retail-store-ui", uri!~"/actuator.*"}[5m]))` |
| 2 | (TBD) 5xx rate | |
| 3 | (TBD) p95 latency | `histogram_quantile(0.95, sum(rate(http_server_requests_seconds_bucket{...}[5m])) by (le))` |

---

## State buckets (do not mix with KubeADM)

- `obs-on-eks-tfstate-obs-725335002991`
- `obs-on-eks-tfstate-workload-725335002991`

AWS account: `725335002991` · region: `us-west-2`
