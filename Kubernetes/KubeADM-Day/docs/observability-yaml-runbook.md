# Observability YAML / Helm Issues — Complete Reference

**Companion to:** [security-groups-runbook.md](security-groups-runbook.md) (infra/network)  
**Covers:** Prometheus, Grafana, node-exporter, kube-state-metrics, Loki, Jaeger, OTEL, Argo GitOps YAML

Every config issue hit during the lab — symptom, root cause, fix, and the file that owns it.

---

## Quick symptom → fix index

| Symptom | Layer | Fix section |
|---------|-------|-------------|
| Grafana multicluster dropdown empty | Prometheus labels | [§2 cluster label](#2-prometheus-cluster-label-external_labels-vs-relabel) |
| `dev targets: 0` in Prometheus | Helm chart v29 | [§3 scrapeConfigs map](#3-prometheus-chart-v29-scrapeconfigs-not-extrasrapeconfigs) |
| Node exporter dashboard obs-only | job label | [§4 job_name](#4-node-exporter-job_name-map-key-trap) |
| ServiceMonitor CRD not found on dev | Prometheus Operator | [§5 no ServiceMonitor on kubeadm](#5-servicemonitor-crd-missing-on-plain-kubeadm) |
| No bundled Grafana after helm upgrade | Chart breaking change | [§6 separate Grafana chart](#6-grafana-not-bundled-in-prometheus-chart-v29) |
| Loki Save & test fails, Explore works | Grafana datasource | [§7 Loki datasource](#7-loki-grafana-datasource-gotchas) |
| `{namespace="order-api"}` empty in Loki | Cross-cluster logs | [§8 dev Promtail](#8-loki-cross-cluster-dev-promtail) |
| Jaeger empty after Argo sync | OTEL YAML + NodePort | [§9 Jaeger / OTEL](#9-jaeger--otel-yaml) |
| Dashboard 6417 empty | Wrong dashboard | [§10 dashboard IDs](#10-grafana-dashboard-ids) |
| Argo reverts kubectl patch | syncPolicy | [§11 Argo selfHeal](#11-argocd-selfheal-vs-manual-kubectl) |
| ImagePullBackOff exec format error | Deployment image | [§12 order-api image](#12-order-api-helm-deployment) |

---

## 1. Architecture: what YAML goes where

```
obs cluster (Helm + manifests)
├── prometheus-community/prometheus     ← scrapeConfigs, KSM, node-exporter subcharts
├── grafana/grafana                     ← datasources (Prometheus, Loki, Jaeger)
├── grafana/loki-stack                  ← Loki + obs Promtail
├── Logs&Monitoring-Day/jaeger.yaml
├── Logs&Monitoring-Day/otel-collector.yaml   ← NodePort 30317
└── argocd install.yaml

dev cluster (Helm via Argo from obs)
├── CICD-Day/helm/order-api/            ← values-kubeadm.yaml + templates
├── install-dev-metrics.sh              ← KSM + node-exporter only (no Prometheus server)
└── install-dev-promtail.sh             ← pushes to obs Loki
```

**Rule:** obs = platform. dev = app + lightweight agents. Cross-cluster = NodePort + values env vars.

---

## 2. Prometheus: `cluster` label — `external_labels` vs relabel

### Symptom

```json
"cluster label values": { "data": [] }
"kube_node_info count by cluster": { "metric": {}, "value": "4" }
```

Grafana dashboards **15757 / 15760** have empty cluster dropdown. Metrics exist but no `cluster` label on stored series.

### Root cause

```yaml
# WRONG for local TSDB queries — only applies on remote write / federation export
server:
  global:
    external_labels:
      cluster: obs
```

`external_labels` tags metrics **leaving** Prometheus, not series **stored** in the local TSDB. Dashboards query stored series with `cluster="$cluster"`.

### Fix

Use **scrape relabel** or **metric_relabel** on every job:

```yaml
metric_relabel_configs:
  - target_label: cluster
    replacement: dev   # or obs
```

Implemented in: `configure-obs-multicluster.sh` (Python-generated values) and base `manifests/obs/prometheus-values.yaml`.

### Verify

```promql
count by (cluster) (kube_node_info)
# Expect: dev + obs
```

**Commit:** `97aada2`

---

## 3. Prometheus chart v29: `scrapeConfigs` not `extraScrapeConfigs`

### Symptom

- `configure-obs-multicluster.sh` runs clean but `dev targets: 0`
- `kubectl get cm prometheus-server -n observability -o yaml | grep dev-` → nothing
- Multicluster script appeared to succeed; Prometheus never loaded dev jobs

### Root cause

Prometheus Helm chart **v28 → v29** moved scrape jobs:

| Old (v28) | New (v29) |
|-----------|-----------|
| `server.extraScrapeConfigs` (YAML string) | `scrapeConfigs` (map at **root**) |
| Array of jobs | Map keys → default `job_name` |

We initially appended to `extraScrapeConfigs` under wrong path or inside wrong block — Helm accepted it but Prometheus config never included dev jobs.

### Fix

`configure-obs-multicluster.sh` generates `/tmp/prometheus-obs-values.yaml` with:

```yaml
scrapeConfigs:
  dev-node-exporter:
    enabled: true
    job_name: node-exporter          # see §4
    static_configs:
      - targets: ["10.110.100.184:9100", ...]
    metric_relabel_configs:
      - target_label: cluster
        replacement: dev
  dev-kube-state-metrics:
    enabled: true
    static_configs:
      - targets: ["10.110.100.184:30301"]
    ...
```

Helm upgrade:

```bash
helm upgrade --install prometheus prometheus-community/prometheus \
  -n observability \
  --set kube-state-metrics.prometheus.monitor.enabled=false \
  --set prometheus-node-exporter.prometheus.monitor.enabled=false \
  -f /tmp/prometheus-obs-values.yaml
```

Also disable default ServiceMonitors (see §5).

### Verify

```bash
curl -s localhost:9090/api/v1/targets | grep -E 'dev|9100|30301'
# dev targets: 5 (4 node-exporter + 1 ksm)
```

**Commits:** `f9f7eef`, `b0de1dd`, `2b91e1d`

---

## 4. Node exporter: `job_name` map key trap

### Symptom

- Prometheus shows targets as `dev-node-exporter` (healthy)
- Grafana **Node Exporter Full (1860)** shows obs only or one node
- PromQL `up{job="node-exporter"}` returns nothing for dev

### Root cause

Chart v29 rule: **map key becomes `job_name`** unless you set `job_name` explicitly.

```yaml
scrapeConfigs:
  dev-node-exporter:    # ← this BECOMES job name
    enabled: true
    relabel_configs:
      - target_label: job
        replacement: node-exporter   # relabel alone did NOT override in targets API
```

Dashboard 1860 filters: `job="node-exporter"` (standard convention).

### Fix

```yaml
dev-node-exporter:
  enabled: true
  job_name: node-exporter    # REQUIRED — explicit override of map key
  static_configs: ...
obs-node-exporter:
  enabled: true
  job_name: node-exporter
  kubernetes_sd_configs: ...
```

Use `cluster` label to distinguish dev vs obs:

```promql
count by (cluster, instance) (up{job="node-exporter"})
# 4 dev + 4 obs
```

**Commits:** `5de46c6`, `3dae4f0`

---

## 5. ServiceMonitor CRD missing on plain kubeadm

### Symptom

```
unable to recognize "": no matches for kind "ServiceMonitor" in version "monitoring.coreos.com/v1"
```

On **dev** when installing full `prometheus-community/prometheus` chart.

### Root cause

Subcharts `kube-state-metrics` and `prometheus-node-exporter` default to creating **ServiceMonitor** / **PodMonitor** CRDs — requires **Prometheus Operator**, which we don't install on kubeadm.

### Fix — dev: agents only, no Prometheus server

`install-dev-metrics.sh`:

```bash
# NOT full prometheus chart on dev
helm upgrade --install kube-state-metrics prometheus-community/kube-state-metrics \
  --set prometheus.monitor.enabled=false \
  --set service.type=NodePort \
  --set service.nodePort=30301

helm upgrade --install node-exporter prometheus-community/prometheus-node-exporter \
  --set prometheus.monitor.enabled=false \
  --set prometheus.podMonitor.enabled=false \
  --set hostNetwork=true
```

**obs** chart install must also disable monitors when using custom scrapeConfigs:

```bash
--set kube-state-metrics.prometheus.monitor.enabled=false
--set prometheus-node-exporter.prometheus.monitor.enabled=false
--set prometheus-node-exporter.prometheus.podMonitor.enabled=false
```

### Why hostNetwork for node-exporter

DaemonSet on `:9100` bound to node IP — obs Prometheus scrapes `10.110.x.x:9100` over VPC. ClusterIP service alone is not enough for cross-cluster static scrape.

**Commit:** `82cfb72`

---

## 6. Grafana not bundled in Prometheus chart v29+

### Symptom

`helm install prometheus` succeeds but no Grafana pod. `install-obs-stack.sh` said "Prometheus + Grafana" but only Prometheus appeared.

### Root cause

`prometheus-community/prometheus` chart **removed bundled Grafana**. Old tutorials assume single chart installs both.

### Fix

Separate Helm release — `manifests/obs/grafana-values.yaml`:

```yaml
adminPassword: cka-lab
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Prometheus
        url: http://prometheus-server
      - name: Loki
        url: http://loki:3100
      - name: Jaeger
        url: http://jaeger:16686
```

```bash
helm upgrade --install grafana grafana/grafana \
  -n observability -f manifests/obs/grafana-values.yaml
```

**Commit:** `829bd55`

---

## 7. Loki + Grafana datasource gotchas

### Symptom A: `curl http://loki:3100` → 404

**Normal.** Loki has no handler on `/`. Valid paths:

| Path | Expected |
|------|----------|
| `/ready` | 200 |
| `/loki/api/v1/labels` | JSON success |
| `/` | 404 (ignore) |

Grafana datasource URL: `http://loki:3100` (no trailing path).

### Symptom B: Save & test red, Explore works

**Grafana UI false negative** on older versions / Loki health check hitting `/`. Trust Explore with real LogQL.

Datasource settings:

| Setting | Value |
|---------|-------|
| Access | **Server** (proxy) — not Browser |
| URL | `http://loki:3100` |

### Symptom C: `{namespace="order-api"}` error or empty

See §8 — not a datasource bug, missing log shipper from dev.

### obs Loki values — NodePort for cross-cluster

`manifests/obs/loki-stack-values.yaml`:

```yaml
loki:
  service:
    type: NodePort
    port: 3100
    nodePort: 30100
promtail:
  config:
    clients:
      - url: http://loki:3100/loki/api/v1/push
        external_labels:
          cluster: obs
```

**Commit:** `dddd4fd`

---

## 8. Loki cross-cluster: dev Promtail

### Symptom

Loki healthy, labels API returns `namespace`, `pod`, etc. — but only **obs** namespaces. `{namespace="order-api"}` empty.

### Root cause

Promtail is **node-local** — tails `/var/log/pods` on nodes where it runs. obs Promtail never sees dev pod stdout.

Same pattern as OTEL: app on dev, backend on obs.

### Fix

`install-dev-promtail.sh` on dev master:

```bash
LOKI_TARGET=10.210.100.57:30100 bash install-dev-promtail.sh
```

Helm values:

```yaml
config:
  clients:
    - url: http://10.210.100.57:30100/loki/api/v1/push
      external_labels:
        cluster: dev
```

### Verify LogQL

```logql
{namespace="order-api", cluster="dev"}
{namespace="order-api", cluster="dev"} |= "order_created"
```

Requires SG **30100** dev → obs (see SG runbook).

---

## 9. Jaeger / OTEL YAML

### Symptom

Jaeger UI empty. order-api running on dev. Argo synced deployment.

### Root causes (three layers)

1. **No OTEL env in deployment** — Helm template lacked `OTEL_*` vars until GitOps commit
2. **Wrong endpoint** — `otel-collector.observability.svc.cluster.local:4317` only resolves **inside obs cluster**, not from dev pods
3. **Argo selfHeal** — manual `kubectl set env` reverted on sync

### Fix — GitOps (Helm)

`values-kubeadm.yaml`:

```yaml
otel:
  enabled: true
  serviceName: order-api
  exporterOtlpEndpoint: http://10.210.100.57:30317
  protocol: grpc
```

`templates/deployment.yaml`:

```yaml
{{- if .Values.otel.enabled }}
- name: OTEL_SERVICE_NAME
  value: {{ .Values.otel.serviceName | quote }}
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: {{ .Values.otel.exporterOtlpEndpoint | quote }}
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: {{ .Values.otel.protocol | quote }}
{{- end }}
```

### Fix — OTel collector NodePort (manifest, not Helm)

`Logs&Monitoring-Day/manifests/otel-collector.yaml`:

```yaml
spec:
  type: NodePort
  ports:
    - name: otlp-grpc
      port: 4317
      nodePort: 30317
```

Re-apply on obs after git pull:

```bash
kubectl apply -f Kubernetes/Logs\&Monitoring-Day/manifests/otel-collector.yaml
```

### Verify

```bash
kubectl exec -n order-api deploy/order-api -- env | grep OTEL
for i in $(seq 1 30); do
  curl -s -X POST http://10.110.100.184:30080/order \
    -H 'Content-Type: application/json' -d '{"item":"t","qty":1}'
done
# Jaeger UI → service: order-api
```

**Commit:** `0b84cb6`

---

## 10. Grafana dashboard IDs

| ID | Name | Works when | Common failure |
|----|------|------------|----------------|
| **6417** | K8s pod monitoring | Single cluster + kube-state-metrics | Empty on multicluster lab — no `cluster` template |
| **15757** | K8s Global View | `cluster` label on metrics | Used `external_labels` instead of relabel |
| **15760** | K8s Namespaces View | `cluster` + KSM from dev | dev KSM not scraped |
| **1860** | Node Exporter Full | `job="node-exporter"` | job was `dev-node-exporter` |

### Dashboard vs Explore debug order

1. Run panel PromQL/LogQL in **Explore** first
2. If Explore has data → dashboard variable/label mismatch
3. If Explore empty → Prometheus/Loki config or scrape (not Grafana)

---

## 11. Argo CD selfHeal vs manual kubectl

### Symptom

`kubectl set env` on order-api works briefly, then OTEL vars disappear.

### Root cause

```yaml
syncPolicy:
  automated:
    selfHeal: true
```

Git is source of truth — manual drift reverted.

### Fix

Change `values-kubeadm.yaml` in git → Argo sync. Or temporarily:

```bash
argocd app set order-api --self-heal=false
```

---

## 12. order-api Helm / deployment

### Image platform (arm64 vs amd64)

```bash
# Symptom: CrashLoopBackOff / exec format error on EC2 amd64
# Fix: build on dev master
cd Kubernetes/Logs\&Monitoring-Day/APP
sudo docker build -t hthaware2508/order-api-lab:v1 .
sudo docker push hthaware2508/order-api-lab:v1
```

### NodePort in Service template

`values-kubeadm.yaml` sets `service.nodePort: 30080` — Service template must conditionally render `nodePort` field (added during lab).

### Prometheus pod annotations

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: /metrics
```

obs Prometheus base values include `kubernetes-pods-annotated` scrape job for in-cluster pods. order-api on **dev** is not scraped by obs unless you add a federate/scrape job — app metrics visible via dev traffic to `/metrics` or add dev scrape job if needed.

### dockerhub-creds secret (dev)

```bash
kubectl create secret docker-registry dockerhub-creds \
  -n order-api \
  --docker-username=... --docker-password=...
```

Referenced in `values-kubeadm.yaml` → `image.pullSecrets`.

---

## 13. File ownership cheat sheet

| Problem area | Own it in |
|--------------|-----------|
| Multicluster Prometheus scrapes | `scripts/configure-obs-multicluster.sh` → `/tmp/prometheus-obs-values.yaml` |
| Base obs Prometheus | `manifests/obs/prometheus-values.yaml` |
| Grafana datasources | `manifests/obs/grafana-values.yaml` |
| Loki NodePort + obs Promtail | `manifests/obs/loki-stack-values.yaml` |
| dev KSM + node-exporter | `scripts/install-dev-metrics.sh` |
| dev → obs logs | `scripts/install-dev-promtail.sh` |
| OTEL collector NodePort | `Logs&Monitoring-Day/manifests/otel-collector.yaml` |
| Jaeger | `Logs&Monitoring-Day/manifests/jaeger.yaml` |
| order-api OTEL env | `CICD-Day/helm/order-api/values-kubeadm.yaml` + `templates/deployment.yaml` |
| GitOps app | `CICD-Day/argocd/application-order-api-kubeadm.yaml` |
| Diagnostics | `scripts/diagnose-multicluster.sh` |

---

## 14. Working config checklist (final state)

Run on **obs** after full setup:

```bash
# Prometheus targets
curl -s localhost:9090/api/v1/targets | python3 -c "
import json,sys
for t in json.load(sys.stdin)['data']['activeTargets']:
  if t['labels'].get('cluster') in ('dev','obs') or 'node' in t['labels'].get('job',''):
    print(t['labels'].get('job'), t['labels'].get('cluster','-'), t['health'])
"

# cluster labels
curl -s 'localhost:9090/api/v1/label/cluster/values'

# node-exporter multicluster
curl -sG 'localhost:9090/api/v1/query' \
  --data-urlencode 'query=count by (cluster,instance) (up{job="node-exporter"})'
```

Expected:

```
dev targets: 5
cluster labels: ["dev","obs"]
node-exporter: 4 dev + 4 obs instances, all up=1
```

Grafana Explore:

```promql
count by (cluster) (kube_node_info)
```

```logql
{namespace="order-api", cluster="dev"}
```

Jaeger: service `order-api` with POST `/order` spans.

---

## 15. Git commits (YAML/config fixes)

| Commit | Fix |
|--------|-----|
| `829bd55` | Separate Grafana Helm chart |
| `97aada2` | cluster label via scrape relabel |
| `82cfb72` | dev metrics without full Prometheus chart |
| `c813717` | Disable ServiceMonitor on kubeadm |
| `f9f7eef` / `b0de1dd` | extraScrapeConfigs path fixes |
| `2b91e1d` | scrapeConfigs map — dev targets finally loaded |
| `5de46c6` / `3dae4f0` | job_name: node-exporter |
| `0b84cb6` | OTEL GitOps in Helm |
| `dddd4fd` | Loki NodePort + dev Promtail |

---

*Infra/network issues: [security-groups-runbook.md](security-groups-runbook.md)*  
*Full lab narrative: [e2e-lab-complete-runbook.md](e2e-lab-complete-runbook.md)*
