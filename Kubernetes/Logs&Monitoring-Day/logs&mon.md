# Logs & Monitoring Day — Notes

Course intro + advanced lab: **Metrics Server**, **logging**, **Prometheus/Loki/Grafana**, and incident triage.

**Lab files:** [lab-guide.md](lab-guide.md) · [load-test.md](load-test.md) · [output.md](output.md)

---

## 1. Three layers of observability

| Layer | Tool | What it answers |
|-------|------|-----------------|
| **Resources** | Metrics Server + `kubectl top` | CPU/memory now — scheduling, HPA |
| **Application metrics** | Prometheus + `/metrics` | Request rate, errors, latency over time |
| **Logs** | stdout → Promtail → Loki | What happened on this request? |

**Not built into Kubernetes** — you install add-ons (Metrics Server, Prometheus, Loki, etc.).

---

## 2. Metrics Server path (course + CKA)

```
cAdvisor (per node, inside kubelet)
  → kubelet summary API
  → Metrics Server (cluster add-on)
  → metrics.k8s.io API
  → kubectl top / HPA
```

| Command | Needs |
|---------|-------|
| `kubectl top nodes` | Metrics Server running in `kube-system` |
| `kubectl top pods -n <ns>` | same |

**Interview line:** Metrics Server gives a **snapshot** for scheduling/HPA — not long-term history. That's Prometheus/Dynatrace.

See Day 16: `Day-16/metric-server.yaml`

---

## 3. Logging fundamentals

### Where logs live

```
App → stdout/stderr
  → container runtime (containerd) writes on node
  → kubelet exposes via API
  → kubectl logs
```

**When pod is deleted → logs are gone** unless shipped to durable storage (Loki, Splunk, ELK).

### CKA commands

```bash
kubectl logs <pod> -n <ns>
kubectl logs <pod> -n <ns> -f                    # follow
kubectl logs <pod> -n <ns> --timestamps
kubectl logs <pod> -n <ns> --since=5m
kubectl logs <pod> -n <ns> --previous              # last crashed container
kubectl logs <pod> -n <ns> -c <container>        # multi-container pod
kubectl logs -n <ns> -l app=order-api            # all replicas
```

**Best practice:** log to **stdout** as **structured JSON** — enables search/alert in Loki/Splunk.

---

## 4. Advanced lab stack (what we built)

```
order-api (Flask + prometheus-client)
  ├── stdout (JSON) → Promtail → Loki → Grafana (LogQL)
  ├── /metrics + pod annotations → Prometheus → Grafana (PromQL)
  └── cAdvisor + kube-state-metrics → Dashboard 6417
```

| Namespace | Contents |
|-------------|----------|
| `order-api` | Deployment, Service, traffic-generator Job |
| `observability` | Loki, Promtail, Grafana, Prometheus (Helm) |

### Prometheus scrape annotations (Deployment)

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/metrics"
```

### Key PromQL (order-api)

```promql
rate(http_requests_total{namespace="order-api"}[1m])
rate(http_requests_total{namespace="order-api",status="503"}[1m])
orders_created_total{namespace="order-api"}
```

### Key LogQL

```logql
{namespace="order-api"}
{namespace="order-api"} |= "payment_gateway_timeout"
{namespace="order-api"} |= "ERROR"
```

---

## 5. Loki + Grafana troubleshooting (learned in lab)

| Symptom | Reality |
|---------|---------|
| `curl http://loki:3100` → 404 | **Normal** — no handler on `/` |
| `/ready` → 200 | Loki is up |
| Save & test red in Grafana | Often false negative — try **Explore** |
| Explore empty | Wrong datasource (Loki vs Prometheus), or time range |

**Verify from Grafana pod** (`-c grafana`):

```bash
curl -s http://loki:3100/ready
curl -s http://loki:3100/loki/api/v1/labels
```

**Datasource settings:** URL `http://loki:3100` · Access **Server** (not Browser)

---

## 6. Dashboard 6417 (imported)

Community dashboard for pod/cluster metrics. Requires:

- `kube-state-metrics` → `kube_pod_info`, etc.
- cAdvisor → `container_cpu_usage_seconds_total`
- Optional: node-exporter

**Some panels empty** → outdated PromQL in community dashboards. Run the panel query in Explore; if no data, metric/label mismatch — not necessarily broken pods.

---

## 7. Incident triage flow (interview)

```
Alert (e.g. 503 rate)
  → 1. Dashboard — confirm spike in reported timeframe
  → 2. kubectl — pods ready? restarts? endpoints populated?
  → 3. Loki — error logs, trace_id / order_id correlation
  → 4. (prod) distributed traces — upstream/downstream (OTel/Tempo — next session)
```

```bash
kubectl get pods -n order-api
kubectl get svc,endpoints -n order-api
kubectl describe pod -n order-api <pod>
kubectl logs -n order-api <pod> --previous
```

| Endpoints | Meaning |
|-----------|---------|
| Empty | No ready pods — selector or probe issue |
| IPs listed | Service layer OK — look at app/logs |

---

## 8. crictl (when kubectl/API is limited)

Modern clusters use **containerd**, not Docker. Debug at runtime level:

```bash
crictl ps
crictl logs <container-id>
crictl inspect <container-id>
```

Use on node when API server is down or kubelet-level issues suspected.

---

## 9. Metrics Server vs Prometheus vs kube-state-metrics

| Component | Purpose |
|-----------|---------|
| **Metrics Server** | `kubectl top`, HPA — short-lived resource usage |
| **Prometheus** | Scrape `/metrics`, history, alerting, dashboards |
| **kube-state-metrics** | K8s object state — pod phase, restarts, labels |

Don't confuse Metrics Server with Prometheus — CKA tests the former; production observability uses the latter.

---

## 10. Load testing

See [load-test.md](load-test.md) — `traffic-generator.yaml` posts to `/order` (~15% intentional 503s).

---

## 11. Coming next

- **OpenTelemetry** — traces correlated with logs (`trace_id`) + metrics
- **CI/CD weekend** — GitHub Actions build/push image, deploy to kind

---

## Quick reference — course summary

**Cluster level:** node metrics → Metrics Server → `metrics.k8s.io` → `kubectl top` / HPA

**Node level:** cAdvisor + pod stats → kubelet → Metrics Server

**Logs:** stdout → runtime on node → `kubectl logs` → (prod) ship to Loki/Splunk/ELK
