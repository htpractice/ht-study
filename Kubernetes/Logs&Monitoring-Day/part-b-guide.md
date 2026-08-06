# Part B — 60-minute runbook (YOU run each step)

**Goal:** OTEL traces → Jaeger · OTEL metrics · Grafana unified alerts · logs correlated via `trace_id`

**Prerequisite:** Part A running (Loki, Prometheus, Grafana, order-api v1)

---

## Architecture

```
order-api v2 (OTEL SDK)
  │ OTLP gRPC :4317
  ▼
otel-collector
  ├── traces → Jaeger (:4317)
  └── metrics → :8889 (Prometheus scrapes)

stdout JSON logs (trace_id) → Promtail → Loki
Prometheus scrapes /metrics + otel-collector:8889

Grafana: Prometheus + Loki + Jaeger datasources → unified alerts
```

---

## Minute 0–10 — Deploy Jaeger + OTEL Collector

```bash
cd ht-study/Kubernetes/Logs\&Monitoring-Day

kubectl apply -f jaeger.yaml
kubectl apply -f otel-collector.yaml

kubectl wait -n observability --for=condition=ready pod -l app=jaeger --timeout=120s
kubectl wait -n observability --for=condition=ready pod -l app=otel-collector --timeout=120s
```

**Verify Jaeger UI:**

```bash
kubectl port-forward -n observability svc/jaeger 16686:16686
# http://localhost:16686
```

---

## Minute 10–20 — Build & deploy order-api v2

```bash
cd APP
docker build -t hthaware2508/order-api-lab:v2 .
docker push hthaware2508/order-api-lab:v2

cd ..
kubectl apply -f order-api-deployment.yaml
kubectl rollout status deployment/order-api -n order-api --timeout=120s
```

**Generate traffic:**

```bash
kubectl apply -f traffic-generator.yaml
# or a few manual curls
```

---

## Minute 20–30 — Jaeger: see traces + attributes

1. Jaeger UI → Service: **order-api** → Find Traces
2. Open a trace — you should see:
   - `POST /order` (Flask auto-instrumentation)
   - child span `create_order` with `order.id`, `product.name`
   - child span `payment.charge` with `payment.result`

**Interview attributes we set (semantic + business):**

| Attribute | Why |
|-----------|-----|
| `service.name`, `service.version` | Resource — identify service in multi-tenant backend |
| `deployment.environment` | Filter lab vs prod |
| `order.id`, `product.name` | Business context in trace |
| `payment.gateway`, `payment.result` | Upstream dependency debugging |
| `http.response.status_code` | Tie trace to HTTP outcome |

---

## Minute 30–40 — Correlate logs ↔ traces

1. Copy a `trace_id` from Jaeger (hex string)
2. Grafana → Explore → **Loki**:

```logql
{namespace="order-api"} |= "<paste-trace-id>"
```

Same request appears in Jaeger **and** Loki — that's end-to-end troubleshooting.

---

## Minute 40–50 — Grafana datasources

Add if missing:

| Datasource | URL |
|------------|-----|
| Jaeger | `http://jaeger:16686` |
| Prometheus | `http://prometheus-server:80` |
| Loki | `http://loki:3100` |

Jaeger in Grafana: Explore → pick Jaeger → search by trace ID.

---

## Minute 50–60 — Grafana unified alerts

See [grafana-alerts.md](grafana-alerts.md) — **you create the rule in UI**.

Quick version:
1. **Alerting → Alert rules → New alert rule**
2. Query A (Prometheus): `rate(http_requests_total{namespace="order-api",status="503"}[5m])`
3. Condition: IS ABOVE `0.05`
4. Save → watch **Alerting → Alert rules** go Pending → Firing under load

---

## Prometheus: scrape OTEL metrics (optional upgrade)

After collector is up, upgrade Prometheus to also scrape `:8889`:

```bash
helm upgrade prometheus prometheus-community/prometheus \
  -n observability -f prometheus-values.yaml
```

Look for OTEL metrics like `orders_created_total` from collector export (may differ from app `/metrics` names).

---

## Alertmanager vs Grafana Alerting (interview)

| | **Prometheus Alertmanager** | **Grafana unified alerting** |
|--|----------------------------|------------------------------|
| Rules live in | Prometheus YAML / CRDs | Grafana UI or provisioning |
| Evaluates | Prometheus only | Prometheus, Loki, multiple sources |
| Notifications | Alertmanager routes | Grafana contact points |
| You used | Prom alertmanager routes | **Grafana alert builder** (this lab) |

Both valid in prod — often Prometheus fires → Alertmanager **or** Grafana manages all rules.

---

## Troubleshooting

| Issue | Check |
|-------|-------|
| No traces in Jaeger | `kubectl logs -n observability -l app=otel-collector` — export errors? |
| order-api can't reach collector | `OTEL_EXPORTER_OTLP_ENDPOINT` env, collector pod ready |
| Empty Jaeger service list | Generate traffic after v2 deploy; wait ~30s |
| Logs missing trace_id | Must be v2 image with OTEL logging correlation |

---

## Cleanup (optional)

```bash
kubectl delete -f jaeger.yaml -f otel-collector.yaml
# rollback: kubectl set image deployment/order-api order-api=hthaware2508/order-api-lab:v1 -n order-api
```
