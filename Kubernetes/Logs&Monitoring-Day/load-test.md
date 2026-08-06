# Load testing order-api — generate metrics + logs to observe

Use these after Prometheus and Loki are running. Allow **1–2 scrape intervals** (~30s) before checking Grafana.

---

## Option 1 — Built-in Job (easiest)

```bash
kubectl apply -f traffic-generator.yaml
kubectl logs -n order-api job/traffic-generator -f
```

Runs 5 minutes: POST `/order` + GET `/health` every 2s. ~15% of orders fail with 503 by design.

---

## Option 2 — Manual curl loop

```bash
for i in $(seq 1 50); do
  curl -s -o /dev/null -w "%{http_code}\n" \
    -X POST http://order-api.order-api.svc.cluster.local/order \
    -H "Content-Type: application/json" \
    -d '{"product":"phone"}'
  sleep 1
done
```

Run from any pod in the cluster, or port-forward the Service first:

```bash
kubectl port-forward -n order-api svc/order-api 8080:80
curl -X POST http://localhost:8080/order -H "Content-Type: application/json" -d '{"product":"phone"}'
```

---

## Option 3 — hey (HTTP load tool)

Install [hey](https://github.com/rakyll/hey) locally, port-forward, then:

```bash
kubectl port-forward -n order-api svc/order-api 8080:80

# 200 requests, 10 concurrent
hey -n 200 -c 10 -m POST \
  -H "Content-Type: application/json" \
  -d '{"product":"laptop"}' \
  http://localhost:8080/order
```

---

## What to watch while load runs

### Terminal

```bash
kubectl top pods -n order-api          # CPU/mem (Metrics Server)
kubectl get pods -n order-api -w       # restarts under pressure?
```

### Grafana — Prometheus Explore

```promql
# Request rate by status
sum(rate(http_requests_total{namespace="order-api"}[1m])) by (status)

# 503 error rate (payment timeouts)
rate(http_requests_total{namespace="order-api",status="503"}[1m])

# Orders successfully created
orders_created_total{namespace="order-api"}
```

### Grafana — Loki Explore

```logql
{namespace="order-api"} |= "order_created"
{namespace="order-api"} |= "payment_gateway_timeout"
```

### Dashboard 6417

Set namespace → `order-api`. Watch CPU/memory panels move under load.

---

## Incident drill (interview practice)

1. Run load test
2. Confirm 503 spike in Prometheus panel
3. `kubectl get pods,svc,endpoints -n order-api`
4. Loki: `{namespace="order-api"} |= "payment_gateway_timeout"`
5. Explain: endpoints OK + 503 in logs → app/upstream issue, not K8s networking

---

## Cleanup

```bash
kubectl delete job traffic-generator -n order-api --ignore-not-found
```
