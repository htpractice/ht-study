# Logs & Monitoring Day — lab output

Cluster: `kind-cka-cluster01` · App: `order-api` · Stack: Loki + Prometheus + Grafana

---

## Summary

| Phase | Result |
|-------|--------|
| Build & push `hthaware2508/order-api-lab:v1` | **OK** |
| Deploy order-api (2 replicas) | **OK** |
| Loki + Promtail + Grafana (Helm) | **OK** — Explore works |
| Prometheus + kube-state-metrics (Helm) | **OK** — scrape delay ~30s normal |
| Dashboard 6417 import | **Partial** — core panels work; some stale queries empty |
| Loki ↔ Grafana Save & test | **Red** — false negative; Explore works |
| Part B — OTEL + Jaeger + alerts | **OK** — traces, log correlation, Grafana alert rules |

**Takeaway:** 404 on `http://loki:3100/` is normal. Verify with `/ready` and `/loki/api/v1/labels`. Empty dashboard panels usually mean metric/label mismatch, not broken pods.

---

## Architecture built

```
order-api (JSON logs + /metrics)
  ├── stdout → Promtail → Loki → Grafana (LogQL)
  ├── annotations → Prometheus scrape → Grafana (PromQL)
  └── cAdvisor/kube-state-metrics → Dashboard 6417
```

---

## Phase 1 — App deploy

```bash
cd APP && docker build -t hthaware2508/order-api-lab:v1 . && docker push hthaware2508/order-api-lab:v1
kubectl apply -f namespace.yaml -f order-api-deployment.yaml -f order-api-service.yaml
```

Both pods `1/1 Running`. Structured JSON logs on stdout. POST `/order` returns 201 or 503 (~15% payment timeout by design).

---

## Phase 2 — Loki troubleshooting (learned)

From Grafana pod (`-c grafana`):

```bash
curl -s http://loki:3100/ready                    # 200 ready
curl -s http://loki:3100/loki/api/v1/labels       # success
curl -s http://loki:3100                          # 404 — expected, not a network failure
```

- Datasource URL: `http://loki:3100` · Access: **Server** (not Browser)
- Save & test red, but Explore + `{namespace="order-api"}` returned logs

---

## Phase 3 — Prometheus + dashboard 6417

```bash
helm install prometheus prometheus-community/prometheus -n observability -f prometheus-values.yaml
helm upgrade prometheus prometheus-community/prometheus -n observability -f prometheus-values.yaml  # enabled kube-state-metrics
```

Grafana datasource: `http://prometheus-server:80`

Dashboard 6417 needed `kube-state-metrics` (`kube_pod_info`). Some panels empty — outdated community queries; core pod/CPU panels work.

**PromQL that works for our app:**

```promql
rate(http_requests_total{namespace="order-api"}[1m])
rate(http_requests_total{namespace="order-api",status="503"}[1m])
orders_created_total{namespace="order-api"}
```

---

## Part B — OTEL, Jaeger, Grafana alerts

Runbook: [part-b-guide.md](part-b-guide.md)

| Step | Result |
|------|--------|
| Deploy `jaeger.yaml`, `otel-collector.yaml` | **OK** |
| Build/push `order-api-lab:v2`, rollout | **OK** |
| Jaeger UI — `POST /order` traces | **OK** — nested spans `create_order`, `payment.charge` |
| Loki ↔ trace_id correlation | **OK** |
| Grafana unified alerts (503 rate) | **OK** — see [grafana-alerts.md](grafana-alerts.md) |

**Note:** Jaeger service list empty until POST traffic after v2 deploy. GET `/health` alone produces minimal traces.

---

## Incident triage flow (interview)

```
Alert (503 rate)
  → 1. Dashboard — confirm spike in reported timeframe
  → 2. kubectl — pods ready? restarts? endpoints populated?
  → 3. Loki — payment_gateway_timeout, trace_id
  → 4. Jaeger — payment.charge span attributes
  → 5. Escalate with timeframe, trace_id, upstream/downstream
```

---

## Key interview lines

| Topic | Answer |
|-------|--------|
| Where do logs live? | Runtime captures stdout on **node**; gone when pod gone unless shipped to Loki/Splunk |
| Metrics Server vs Prometheus | Metrics Server → `kubectl top`/HPA snapshot; Prometheus → history, alerting, dashboards |
| Empty dashboard panel | Run panel PromQL in Explore; check metric exists + labels match |
| 502 vs 503 in our lab | 502 = can't reach backend (Service/targetPort); 503 = app rejected request (payment timeout) |

---

## Load test

See [load-test.md](load-test.md) — `traffic-generator.yaml` or `hey` against port-forward.

---

## Full command logs

Raw output: [practice-ou.md](practice-ou.md) (build/deploy), [practice-op.md](practice-op.md) (Loki debug).
