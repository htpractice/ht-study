# Logs & Monitoring — Advanced Lab Guide

Beyond CKA basics (`kubectl top`, `kubectl logs`). This lab builds a **real observability stack** on your kind cluster:

```
App stdout (JSON logs)  →  Promtail  →  Loki  →  Grafana (LogQL)
App /metrics            →  Prometheus scrape  →  Grafana (PromQL)
Kubelet/cAdvisor        →  Metrics Server     →  kubectl top / HPA
```

Cluster: `kind-cka-cluster01` (metrics-server already installed)

Run `kubectl` / `helm` from the **lab root** (`Logs&Monitoring-Day/`); manifests live in `manifests/`.

---

## Phase 0 — What your course covered (baseline)

| Layer | Tool | What it gives you |
|-------|------|-------------------|
| Resource usage | Metrics Server + `kubectl top` | CPU/memory per pod/node |
| App logs | `kubectl logs` | stdout/stderr from containers |
| Node/runtime debug | `crictl` | When API/kubectl isn't enough |

**Gap:** no search, no dashboards, no correlation, no metrics history. That's what we add.

---

## Phase 1 — Build, push, deploy (you run this)

The **order-api** uses Flask + `prometheus-client` — real histograms/counters, not hand-rolled metrics.

### Step 1 — Build & push

```bash
cd ht-study/Kubernetes/Logs\&Monitoring-Day/APP

docker build -t hthaware2508/order-api-lab:v1 .
docker push hthaware2508/order-api-lab:v1
```

Verify locally before pushing:

```bash
docker run --rm -p 8080:8080 hthaware2508/order-api-lab:v1
curl localhost:8080/health
curl localhost:8080/metrics | head
```

### Step 2 — Deploy to cluster

```bash
cd ..
kubectl apply -f manifests/namespace.yaml
kubectl apply -f manifests/order-api-deployment.yaml
kubectl apply -f manifests/order-api-service.yaml

kubectl wait -n order-api --for=condition=ready pod -l app=order-api --timeout=120s
kubectl get pods,svc -n order-api
```

If `ImagePullBackOff`: check `docker push` succeeded and image name matches deployment.

```bash
kubectl describe pod -n order-api -l app=order-api | grep -A3 Events
```

**Generate traffic:** see [load-test.md](load-test.md)

---

## Phase 2 — Advanced logging (kubectl + JSON)

### Basic → advanced `kubectl logs`

```bash
# Follow live logs from all replicas
kubectl logs -n order-api -l app=order-api -f

# One pod, timestamps
kubectl logs -n order-api <pod-name> --timestamps

# Last 5 minutes only
kubectl logs -n order-api <pod-name> --since=5m

# Previous crashed container (critical for CrashLoopBackOff)
kubectl logs -n order-api <pod-name> --previous

# Multi-container pod (when you add sidecars later)
kubectl logs -n order-api <pod-name> -c order-api
```

### Why structured JSON matters

Raw log:
```json
{"timestamp":"2026-08-06T...","level":"ERROR","message":"payment_gateway_timeout","trace_id":"a1b2c3d4","order_id":"ord-abc123"}
```

In production, **Promtail → Loki** indexes labels; you query with **LogQL** instead of grep.

### Filter JSON locally (quick win before Loki)

```bash
kubectl logs -n order-api -l app=order-api --tail=100 | grep payment_gateway_timeout
kubectl logs -n order-api -l app=order-api --tail=200 | grep '"level":"ERROR"'
```

---

## Phase 3 — Install Loki stack (log aggregation)

Promtail runs as a **DaemonSet** (one agent per node) — same pattern as Fluent Bit, Datadog agent, etc.

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install loki grafana/loki-stack \
  -n observability --create-namespace \
  -f manifests/loki-stack-values.yaml
```

Wait for pods:

```bash
kubectl wait -n observability --for=condition=ready pod -l app.kubernetes.io/name=grafana --timeout=180s
kubectl get pods -n observability
```

**Access Grafana:**

```bash
kubectl port-forward -n observability svc/loki-grafana 3000:80
```

Open http://localhost:3000 — user `admin`, password `cka-lab`.

### Add Loki datasource (if not auto-configured)

1. Grafana → Connections → Data sources → Add **Loki**
2. URL: `http://loki:3100`
3. Save & test

### LogQL queries to try

```logql
# All logs from order-api namespace
{namespace="order-api"}

# Errors only (JSON parsing)
{namespace="order-api"} |= "ERROR"

# Payment failures
{namespace="order-api"} |= "payment_gateway_timeout"

# Rate of error log lines per minute
sum(rate({namespace="order-api"} |= "ERROR" [1m]))
```

---

## Phase 4 — Install Prometheus (metrics)

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/prometheus \
  -n observability \
  -f manifests/prometheus-values.yaml
```

Verify scrape targets:

```bash
kubectl port-forward -n observability svc/prometheus-server 9090:80
```

Open http://localhost:9090 → Status → Targets. Look for `kubernetes-pods-annotated` with `order-api` pods **UP**.

### Add Prometheus datasource in Grafana

1. Connections → Data sources → Add **Prometheus**
2. URL: `http://prometheus-server:80`
3. Save & test

### PromQL queries to try

```promql
# Request rate
rate(http_requests_total{kubernetes_namespace="order-api"}[1m])

# 503 errors (payment timeouts)
rate(http_requests_total{kubernetes_namespace="order-api",status="503"}[1m])

# p95 latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{kubernetes_namespace="order-api"}[5m]))

# Orders created
orders_created_total{kubernetes_namespace="order-api"}
```

---

## Phase 5 — Correlate logs + metrics (the SRE move)

When alerts fire on high 503 rate in Prometheus:

1. Note the timestamp
2. Switch to Loki → `{namespace="order-api"} |= "payment_gateway_timeout"`
3. Grab `trace_id` / `order_id` from JSON log
4. Cross-check pod: `kubectl describe pod -n order-api <pod>`

This is how platform/observability engineers debug in prod (Dynatrace, Datadog, Grafana Cloud — same idea).

---

## Phase 6 — Resource monitoring (Metrics Server)

You already have this — connect the dots:

```bash
kubectl top pods -n order-api
kubectl top nodes

# Compare with Prometheus (more history) vs kubectl top (snapshot)
```

Data path: **cAdvisor → kubelet → Metrics Server → metrics.k8s.io API → kubectl top / HPA**

---

## Phase 7 — crictl (when kubectl isn't enough)

SSH/exec into a node (kind: `docker exec -it cka-cluster01-control-plane bash`):

```bash
# List containers on the node
crictl ps

# Logs directly from runtime (bypasses API server)
crictl logs <container-id>

# Inspect failed container
crictl inspect <container-id> | jq .status.state
```

Use when: API server down, kubelet issues, control plane debugging.

On kind control-plane node, crictl is pre-installed.

---

## Phase 8 — Interview & CKA checklist

**CKA must-know:**
- `kubectl logs`, `--previous`, `-c`, `-f`, `--timestamps`
- `kubectl top pods/nodes` (needs Metrics Server)
- Debug failing pod: `describe pod`, `logs --previous`, events
- Know logs go to stdout/stderr; cluster doesn't store them forever

**Interview advanced:**
- **Pull vs push metrics:** Prometheus pulls `/metrics`; agents can push (Pushgateway, OTEL)
- **Log pipeline:** app → stdout → node agent (Promtail/Fluent Bit) → Loki/ELK/Splunk
- **DaemonSet pattern:** one log/metrics agent per node
- **RED metrics:** Rate, Errors, Duration for services
- **USE metrics:** Utilization, Saturation, Errors for resources
- **Structured logging:** JSON fields enable query/alert; plain strings don't scale
- **Sidecar vs stdout:** prefer stdout; sidecar for legacy apps that log to files

---

## Cleanup

```bash
helm uninstall prometheus -n observability
helm uninstall loki -n observability
kubectl delete ns order-api observability
```

---

## Next steps

- **Part B (done in repo):** [part-b-guide.md](part-b-guide.md) — OTEL collector, Jaeger, Grafana unified alerts
- CI/CD weekend — GitHub Actions build/push/deploy `order-api`
- Gateway API / ServiceMonitor with kube-prometheus-stack (heavier, production-grade)
