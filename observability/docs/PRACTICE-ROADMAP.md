# obs-on-eks — Practice Roadmap (CKA / kubeastronaut)

**Goal:** Hands-on observability fluency — PromQL, SLO panels, three-pillar triage (metrics / logs / traces).  
**Path:** CKA → CKS/kubeastronaut with real workload patterns on EKS.  
**Lab runtime:** Full day OK (~$0.55/hr both clusters ≈ **$4–5 for 8h**). Destroy when done.

---

## Where you are now (~55% → target 75%)

| Area | Status | Evidence |
|------|--------|----------|
| **Observability & keyboard queries** | 🟡 Strong start | Loki → Jaeger → PromQL path; Panel 1; metric discovery CLI |
| **Incident storytelling** | 🟢 Covered | 18s UI / catalog timeout trace — use as **lab STAR story** |
| **PromQL depth** | 🔴 Gap | Need rate, ratio, histogram, aggregation by label, multi-service |
| **SLO/SLI / error budget** | 🔴 Gap | Build dashboard **today PM**; tie to burn-rate language |
| **Distributed systems under stress** | 🟡 | Jun Webhooks story + today's catalog dependency — connect both |
| **Event pipelines (Kafka bridge)** | 🟡 | Stories ready; map queue lag ↔ SQS in interview |
| **K8s / platform ops** | 🟡 | Lab + kubeadm; rehearse drain/PDB if asked |
| **Capacity / DR vocabulary** | 🟡 | Know RPO/RTO table — 15 min review |

**Your edge:** Real on-call observability ownership (Dynatrace/SLO YAML) + **today you did hands-on three-pillar triage** — most candidates only talk about it.

---

## Full-day schedule (adjust times)

### Block 1 — Morning ✅ (done)

- [x] Deploy + verify three signals
- [x] First troubleshoot (UI slow → Loki → Jaeger → catalog spans)
- [x] Panel 1: UI request rate
- [x] Infra metrics → Grafana namespace dropdown

### Block 2 — PromQL bootcamp (2–3 hr) ← **now**

Work in Grafana Explore → Prometheus. Type every query yourself; don't paste from doc until you've tried once.

**Level 1 — Existence & labels (15 min)**

```promql
up{namespace="retail-store"}
http_server_requests_seconds_count{app_kubernetes_io_instance="retail-store-ui"}
```

Exercise: list all `app_kubernetes_io_instance` values in retail-store.

**Level 2 — Rates (30 min)**

```promql
# RPS per service
sum by (app_kubernetes_io_instance) (
  rate(http_server_requests_seconds_count{namespace="retail-store", uri!~"/actuator.*"}[5m])
)

# UI only (Panel 1)
sum(rate(http_server_requests_seconds_count{app_kubernetes_io_instance="retail-store-ui", uri!~"/actuator.*"}[5m]))
```

Generate store traffic between queries; watch line move.

**Level 3 — Error rate / availability SLI (45 min)**

Spring uses `status` label (200, 404, 500), not `5xx` regex on metric name.

```promql
# 5xx rate (UI)
sum(rate(http_server_requests_seconds_count{
  app_kubernetes_io_instance="retail-store-ui",
  status=~"5..",
  uri!~"/actuator.*"
}[5m]))

# Availability SLI proxy (good / total) — interview gold
sum(rate(http_server_requests_seconds_count{
  app_kubernetes_io_instance="retail-store-ui",
  status=~"2..",
  uri!~"/actuator.*"
}[5m]))
/
sum(rate(http_server_requests_seconds_count{
  app_kubernetes_io_instance="retail-store-ui",
  uri!~"/actuator.*"
}[5m]))
```

Go services (catalog): same pattern but metric may be on `/metrics` with different label names — run discovery:

```bash
kubectl --context obs-eks exec -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=http_server_requests_seconds_count{app_kubernetes_io_instance="retail-store-catalog"}' | jq '.data.result[0].metric'
```

**Level 4 — Latency SLI (45 min)**

Micrometer exposes a **summary** → use `_count` + `_sum` or histogram if present:

```promql
# Avg latency (seconds) — UI
sum(rate(http_server_requests_seconds_sum{app_kubernetes_io_instance="retail-store-ui", uri!~"/actuator.*"}[5m]))
/
sum(rate(http_server_requests_seconds_count{app_kubernetes_io_instance="retail-store-ui", uri!~"/actuator.*"}[5m]))
```

If `_bucket` exists:

```promql
histogram_quantile(0.95,
  sum by (le) (rate(http_server_requests_seconds_bucket{app_kubernetes_io_instance="retail-store-ui"}[5m]))
)
```

**Level 5 — Infra + app combined (30 min)**

```promql
# CPU per retail pod
sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="retail-store", container!=""}[5m]))

# Memory working set
container_memory_working_set_bytes{namespace="retail-store", pod=~"retail-store-ui.*"}
```

**Level 6 — Keyboard drill (30 min)**

Timer: 5 min each — write from memory:

1. Is catalog up?
2. RPS for all retail services?
3. UI 5xx rate?
4. UI p95 latency (or avg if no buckets)?
5. Which pod uses most CPU in retail-store?

---

### Block 3 — SLO/SLI dashboard (2 hr) — **later today**

Build **Retail Store — SLO Lab** dashboard in Grafana.

| Panel | SLI | Query sketch | SLO line |
|-------|-----|--------------|----------|
| 1 | Request rate | Panel 1 query | — |
| 2 | Availability | good/total ratio above | 99.9% (0.999) |
| 3 | Error budget burn | `1 - availability` over 1h window | talk track |
| 4 | Latency p95 | histogram_quantile | e.g. < 500ms |
| 5 | Saturation | CPU / memory per UI pod | 80% warn |

**Interview talk track (30 sec):**

> SLI = measured good/total from Prometheus. SLO = 99.9% over 30d. Error budget = 0.1%. We alert on burn rate — fast burn pages, slow burn ticket. Same pattern as observability-registry → Dynatrace at Autodesk.

**Burn-rate style (simplified PromQL for lab):**

```promql
# 1h availability — compare to 0.999
avg_over_time(
  (
    sum(rate(http_server_requests_seconds_count{app_kubernetes_io_instance="retail-store-ui", status=~"2..", uri!~"/actuator.*"}[5m]))
    /
    sum(rate(http_server_requests_seconds_count{app_kubernetes_io_instance="retail-store-ui", uri!~"/actuator.*"}[5m]))
  )[1h:5m]
)
```

Add Grafana threshold: red if < 0.999.

---

### Block 4 — Three-pillar incident drill (1 hr)

Repeat today's flow **without looking at notes** — timer 20 min:

1. **Break it:** hit UI after catalog rollout / heavy traffic
2. **Loki:** find 500 + timestamp
3. **Jaeger:** find trace, slow span, exception event
4. **Prometheus:** error rate + latency at same window
5. **Say out loud:** Detect → Triage → Mitigate → Communicate → PM → Prevent

**Story bridge to production SRE:**

| Lab | Production (Webhooks/NOTIFI) |
|-----|------------------------------|
| Loki 500 on UI GET | Splunk failed delivery / Apigee 5xx |
| Jaeger catalog span 10s | Dynatrace trace_id across WH → L3 → PubNub |
| PromQL error rate | SLO burn on AddEventHook |
| Cold start / timeout | Connection pool + Lambda burst scaling |

---

### Block 5 — Platform SRE rapid fire (1 hr)

For each area, say **one sentence + one proof** from lab or work:

1. **Reliability** — SLO / error budget / burn-rate language
2. **Distributed stress** — fan-out, retry queue, upstream vs downstream SLI
3. **Event pipelines** — queue depth = consumer lag; split failure modes
4. **Incidents** — Detect → Triage → Mitigate → Fix forward
5. **Observability** — **this lab** (Prometheus / Loki / Jaeger)
6. **Capacity/DR** — scale limits, PDB/drain, multi-AZ / multicluster

Rehearse one **lab STAR story** (catalog latency / cart chaos) at 90 sec.

---

### Block 6 — LogQL + cross-signal (45 min)

```logql
{cluster="retail-workload", namespace="retail-store"} |= "error"
{cluster="retail-workload", app_kubernetes_io_instance="retail-store-ui"} |~ "5[0-9]{2}"
```

Exercise: pick a log line timestamp → same window in Jaeger + PromQL.

---

### Block 7 — Optional stretch

- [ ] Break obs peering (mental only): what fails first — metrics, logs, or traces?
- [ ] `kubectl drain` on workload node — tie to PDB story
- [ ] Export dashboard JSON to git

---

## 70–80% readiness checklist

Check off when comfortable:

- [ ] Write 5 PromQL queries from memory in < 5 min each
- [ ] Explain SLI vs SLO vs error budget vs burn rate in 30 sec
- [ ] Tell lab troubleshoot story in 90 sec (STAR)
- [ ] Map queue lag / consumer lag in one sentence
- [ ] Draw three-pillar triage on whiteboard (metrics/logs/traces)
- [ ] Know what's on `:9090/metrics` vs `/api/v1/query` vs app `/actuator/prometheus`
- [ ] SLO dashboard with ≥4 panels saved in Grafana

---

## PromQL cheat sheet — retail-store naming

| Interview generic | This lab (Spring Boot) |
|-------------------|------------------------|
| `http_requests_total` | `http_server_requests_seconds_count` |
| `status="500"` or `=~"5.."` | same — check `status` label |
| `service="ui"` | `app_kubernetes_io_instance="retail-store-ui"` |
| `job="ui"` | `job="kubernetes-pods"` |

---

## Cost reminder (full day)

| Duration | ~Cost |
|----------|-------|
| 8 hr | ~$4.50–5.00 |
| 12 hr | ~$6.50–7.00 |

Destroy when done: `bash scripts/destroy-infra.sh`

---

## Related docs

- [TROUBLESHOOTING-REF.md](./TROUBLESHOOTING-REF.md) — commands, incidents, endpoints
- [LAB-SPEC.md](./LAB-SPEC.md) — deploy/teardown
- [REFERENCES.md](./REFERENCES.md) — upstream kind/local lab clones
