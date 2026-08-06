# Grafana unified alerting — Part B lab

Grafana **alert builder** (Grafana 8+) replaces the old workflow where only Prometheus Alertmanager handled notifications. You can still run Alertmanager in prod — this lab uses **Grafana-native rules** so one UI manages Prometheus + Loki alerts.

---

## Setup contact point (optional — see firing in UI without Slack)

1. **Alerting → Contact points → New contact point**
2. Name: `lab-default`
3. Integration: **Email** or **Webhook** (or skip — rules still show Firing in UI)

For lab-only: skip contact point; watch **Alerting → Alert rules** status column.

---

## Alert 1 — High 503 rate (Prometheus)

Simulates on-call page when payment timeouts spike.

1. **Alerting → Alert rules → + New alert rule**
2. Name: `order-api-high-503-rate`
3. Folder: `order-api` (create if needed)
4. **Section A — Query**
   - Datasource: **Prometheus**
   - Query:

```promql
sum(rate(http_requests_total{namespace="order-api",status="503"}[5m]))
```

   - Legend: `503 rate`

5. **Section B — Expression** (Grafana 9+)
   - Operation: **Threshold**
   - Input: A
   - IS ABOVE: `0.02` (adjust — ~15% errors under load may need tuning)

6. **Section C — Set evaluation**
   - Evaluate every: `1m`
   - For: `2m` (must breach for 2 min before firing)

7. **Add annotations** (optional):
   - Summary: `order-api 503 rate elevated`
   - Description: `Check Loki for payment_gateway_timeout; verify endpoints`

8. **Save**

**Test:** run `traffic-generator.yaml`, wait 2–3 min, refresh Alert rules page.

---

## Alert 2 — Error logs (Loki)

1. **New alert rule**
2. Name: `order-api-payment-errors`
3. Query A (Loki):

```logql
sum(count_over_time({namespace="order-api"} |= "payment_gateway_timeout" [5m]))
```

4. Threshold: IS ABOVE `5`
5. Evaluate every `1m`, for `1m`

**Interview line:** "Grafana can alert on log patterns directly — no need to metricize every log line first."

---

## Grafana vs Alertmanager — when to use which

| Use Grafana alerting | Use Alertmanager |
|---------------------|------------------|
| Team lives in Grafana | Team standardizes on Prometheus CRDs / GitOps |
| Loki + Prometheus rules together | Prometheus-only, mature routing tree |
| Contact points in Grafana Cloud stack | Complex inhibition/silencing at scale |

**Hybrid (common in prod):** Prometheus rules → Alertmanager for paging; Grafana for dashboards + optional duplicate alerts.

---

## Incident flow with alerts (ties Part A + B)

```
Grafana alert: 503 rate firing
  → Dashboard: confirm timeframe + magnitude
  → kubectl: pods, endpoints
  → Loki: payment_gateway_timeout + trace_id
  → Jaeger: open trace → see payment.charge span failed
  → Fix / escalate payment gateway team
```

---

## PromQL / LogQL cheat sheet for alerts

```promql
# Pod restarts (needs kube-state-metrics)
increase(kube_pod_container_status_restarts_total{namespace="order-api"}[15m]) > 0

# Request error ratio
sum(rate(http_requests_total{namespace="order-api",status=~"5.."}[5m]))
/ sum(rate(http_requests_total{namespace="order-api"}[5m]))
```

```logql
# Any ERROR level JSON
{namespace="order-api"} |= `"level":"ERROR"`
```
