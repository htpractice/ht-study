# E2E Kubeadm Lab — Complete Runbook (11-Hour Build)

> **Setup spec (agents + users):** [LAB-SPEC.md](LAB-SPEC.md) — start here to reproduce the lab.

**Branch:** `cka-2026-study` · **Repo:** [htpractice/ht-study](https://github.com/htpractice/ht-study)  
**Completed:** August 10, 2026 · **Region:** `us-west-2` · **AWS Account:** `725335002991`

This document captures **everything** that made the lab work end-to-end.

**Deep dives (read these for revision):**
- **Infra / SG:** [security-groups-runbook.md](security-groups-runbook.md)
- **YAML / Helm / Grafana / Prom / Loki / Jaeger:** [observability-yaml-runbook.md](observability-yaml-runbook.md)

---

## Table of contents

1. [What we built](#1-what-we-built)
2. [Architecture](#2-architecture)
3. [AWS inventory (live snapshot)](#3-aws-inventory-live-snapshot)
4. [VPC peering (manual)](#4-vpc-peering-manual)
5. [Security groups & cross-VPC ports](#5-security-groups--cross-vpc-ports)
6. [Terraform & GitHub Actions](#6-terraform--github-actions)
7. [Cluster bootstrap sequence](#7-cluster-bootstrap-sequence)
8. [GitOps — order-api on dev via Argo on obs](#8-gitops--order-api-on-dev-via-argo-on-obs)
9. [Observability stack](#9-observability-stack)
10. [Cross-cluster data flows (NodePorts)](#10-cross-cluster-data-flows-nodeports)
11. [Verification commands](#11-verification-commands)
12. [Grafana dashboards & queries](#12-grafana-dashboards--queries)
13. [Troubleshooting encyclopedia](#13-troubleshooting-encyclopedia)
14. [Interview stories earned](#14-interview-stories-earned)
15. [Pre-teardown capture](#15-pre-teardown-capture)
16. [Teardown](#16-teardown)
17. [File index](#17-file-index)
18. [Git commit timeline](#18-git-commit-timeline)

---

## 1. What we built

| Layer | dev cluster (`10.110.0.0/16`) | obs cluster (`10.210.0.0/16`) |
|-------|-------------------------------|-------------------------------|
| **Purpose** | App workload (order-api) | Observability + GitOps control plane |
| **Nodes** | 1 CP + 3 workers | 1 CP + 3 workers |
| **CNI** | Flannel (`10.244.0.0/16`) | Flannel (`10.244.0.0/16`) |
| **K8s** | v1.35.7 (kubeadm) | v1.35.7 (kubeadm) |
| **App** | order-api × 3 (NodePort 30080) | — |
| **Metrics agents** | kube-state-metrics + node-exporter | Full Prometheus + Grafana |
| **Logs** | Promtail → obs Loki | Loki + Promtail (local) |
| **Traces** | OTEL SDK → obs collector | Jaeger + OTel Collector |
| **GitOps** | Target cluster for Argo CD | Argo CD server |

**Three pillars working end-to-end:**

```
Metrics:  dev order-api + node metrics ──scrape──► obs Prometheus ──► Grafana
Traces:   dev order-api ──OTLP──► obs OTel Collector ──► Jaeger
Logs:     dev order-api stdout ──Promtail──► obs Loki ──► Grafana Explore
```

---

## 2. Architecture

```
┌──────────────────────────────── dev VPC 10.110.0.0/16 ────────────────────────────────┐
│                                                                                       │
│  order-api (3 replicas)          kube-state-metrics          node-exporter            │
│  NodePort :30080                 NodePort :30301             hostNetwork :9100        │
│       │                               ▲                           ▲                   │
│       │ OTLP :30317                   │ scrape                    │ scrape            │
│       │                               │                           │                   │
│  Promtail (DaemonSet) ──push :30100───┼───────────────────────────┼───────────────────┤
│                                       │                           │                   │
└───────────────────────────────────────┼───────────────────────────┼─────────────────┘
                                        │    VPC Peering pcx-0a20139fd655d1170          │
┌───────────────────────────────────────┼───────────────────────────┼─────────────────┐
│                                       ▼                           ▼                 │
│  obs VPC 10.210.0.0/16                                                                │
│                                                                                       │
│  Argo CD ──6443──► dev API          Prometheus (multicluster scrapeConfigs)           │
│  Grafana ◄── Prometheus / Loki / Jaeger                                               │
│  Loki :30100 (NodePort) ◄── dev Promtail                                              │
│  OTel Collector :30317 ◄── dev order-api                                              │
│  Jaeger ◄── OTel Collector                                                            │
│                                                                                       │
└───────────────────────────────────────────────────────────────────────────────────────┘
```

**Design principle:** Single pane of glass on **obs**. Dev runs minimal agents (metrics + log shipper); obs runs the observability platform and Argo CD.

---

## 3. AWS inventory (live snapshot)

Captured from AWS API before teardown documentation (August 10, 2026).

### EC2 instances

| Name | Env | Instance ID | Private IP | Public IP | SG |
|------|-----|-------------|------------|-----------|-----|
| dev-k8s-m1 | dev | i-021686b7b7013a394 | **10.110.100.184** | 18.236.111.76 | sg-08c4616d57cc9af82 |
| dev-k8s-w1 | dev | i-032e959a6ae8df281 | 10.110.100.179 | 35.93.115.54 | sg-026a5d2b7c69cdbdc |
| dev-k8s-w2 | dev | i-0f10684f787bcd4aa | 10.110.104.224 | 16.147.24.39 | sg-026a5d2b7c69cdbdc |
| dev-k8s-w3 | dev | i-06de6a051ffd7cbc7 | 10.110.100.30 | 34.222.27.91 | sg-026a5d2b7c69cdbdc |
| obs-k8s-m1 | obs | i-0789e7e18983d361d | **10.210.100.57** | 54.218.254.122 | sg-04f339552dae38dd5 |
| obs-k8s-w1 | obs | i-0a7cab02ebf352776 | 10.210.100.35 | 16.144.82.173 | sg-09881b6ca704e5ba9 |
| obs-k8s-w2 | obs | i-0d453833cf0111c18 | 10.210.104.147 | 35.165.36.1 | sg-09881b6ca704e5ba9 |
| obs-k8s-w3 | obs | i-0b2f2bdb99ac6edc2 | 10.210.100.26 | 34.222.96.164 | sg-09881b6ca704e5ba9 |

**Key IPs used in configs:**

| Purpose | IP |
|---------|-----|
| dev master (KSM NodePort, DEV_TARGET) | `10.110.100.184` |
| obs master (OTEL, Loki NodePort target) | `10.210.100.57` |

### VPCs

| VPC ID | CIDR | Environment |
|--------|------|-------------|
| vpc-060e4c86a7960afac | 10.110.0.0/16 | dev |
| vpc-08b3aac554cb58c9b | 10.210.0.0/16 | obs |

### VPC peering

| Peering ID | Requester | Accepter | Status |
|------------|-----------|----------|--------|
| **pcx-0a20139fd655d1170** | obs 10.210.0.0/16 (vpc-08b3aac554cb58c9b) | dev 10.110.0.0/16 (vpc-060e4c86a7960afac) | active |

### Security groups

| SG ID | Name pattern | Role |
|-------|--------------|------|
| sg-08c4616d57cc9af82 | dev-kubeadm-control-plane-sg | dev CP |
| sg-026a5d2b7c69cdbdc | dev-kubeadm-worker-node-sg | dev workers |
| sg-04f339552dae38dd5 | obs-kubeadm-control-plane-sg | obs CP |
| sg-09881b6ca704e5ba9 | obs-kubeadm-worker-node-sg | obs workers |

### Terraform state (S3)

| Bucket | State key |
|--------|-----------|
| cka-2026-study-terraform-state-dev | environments/dev/terraform.tfstate |
| cka-2026-study-terraform-state-obs | environments/obs/terraform.tfstate |
| cka-2026-study-terraform-state-prod | environments/prod/terraform.tfstate |

### SSH keys

| Env | Key location |
|-----|--------------|
| dev | `kubeadm-on-ec2/dev/private_key.pem` (local from terraform) |
| obs | AWS Secrets Manager `kubeadm/obs/ssh-private-key` |

---

## 4. VPC peering (manual)

**Not in Terraform** — configured in AWS Console/CLI after both VPCs exist.

### Steps performed

1. **Create peering** obs ↔ dev → `pcx-0a20139fd655d1170`
2. **Accept** peering connection
3. **Enable DNS resolution** on both sides (peering options)
4. **Add routes** on all route tables (public + private) in both VPCs:
   - dev RTs → `10.210.0.0/16` via peering
   - obs RTs → `10.110.0.0/16` via peering

### Verify

```bash
# From obs master
ping -c 2 10.110.100.184
nc -vz 10.110.100.184 6443   # dev API (after SG rule)
nc -vz 10.110.100.184 9100   # node-exporter
nc -vz 10.110.100.184 30301  # kube-state-metrics

# From dev master
nc -vz 10.210.100.57 30317   # OTel
nc -vz 10.210.100.57 30100   # Loki
```

**Interview line:** Peering is the **attachment**; routes are the **map**; security groups are the **bouncer**. All three required.

---

## 5. Security groups & cross-VPC ports

> **Full SG reference (live AWS + Terraform drift):** [security-groups-runbook.md](security-groups-runbook.md)

### Cross-VPC port matrix (critical for lab)

| Port | Protocol | Direction | Purpose |
|------|----------|-----------|---------|
| **6443** | TCP | obs → dev CP | Argo CD cross-cluster API |
| **9100** | TCP | obs → dev all nodes | Prometheus scrape node-exporter |
| **30301** | TCP | obs → dev master | Prometheus scrape kube-state-metrics |
| **30317** | TCP | dev → obs | OTLP gRPC (order-api → OTel) |
| **30100** | TCP | dev → obs | Promtail → Loki push |
| **8472** | UDP | within each VPC `/16` | Flannel VXLAN (pod cross-node traffic) |

### Flannel gotcha

SG must allow UDP **8472** from **full VPC CIDR** (`10.110.0.0/16`), not just subnet `/24`. Using `/24` breaks pod-to-pod traffic across nodes in different subnets.

### NodePort gotcha

Worker SG NodePort rules (`30000-32767`) often only allow **same VPC CIDR**. Cross-VPC access needs **explicit rules** per port (30100, 30317, 9100, 30301).

---

## 6. Terraform & GitHub Actions

### Layout

```
Kubernetes/KubeADM-Day/kubeadm-on-ec2/
├── dev/     # app cluster
├── obs/     # observability cluster
└── prod/    # future — manual GHA only
```

### tfvars summary

**dev** (`dev/dev.tfvars`):

```hcl
environment  = "dev"
vpc_cidr     = "10.110.0.0/16"
public_subnets  = ["10.110.100.0/24", "10.110.104.0/24"]
private_subnets = ["10.110.1.0/24", "10.110.4.0/24"]
instance_type = "t3.small"
ami           = "ami-02167eae61967e403"
```

**obs** (`obs/obs.tfvars`):

```hcl
environment  = "obs"
vpc_cidr     = "10.210.0.0/16"
public_subnets  = ["10.210.100.0/24", "10.210.104.0/24"]
private_subnets = ["10.210.1.0/24", "10.210.4.0/24"]
```

### Workflows

| Workflow | Trigger | Action |
|----------|---------|--------|
| `.github/workflows/kubeadm-terraform.yaml` | Push to `cka-2026-study` (path: `kubeadm-on-ec2/**`) | Plan + apply **dev + obs** (approval gates) |
| `.github/workflows/kubeadm-terraform-destroy.yaml` | Manual `workflow_dispatch`, type `destroy` | Destroy single env |

**CI note:** `TF_VAR_copy_scripts_via_ssh=false` in GHA — scripts copied manually via `copy-scripts-to-nodes.sh`.

---

## 7. Cluster bootstrap sequence

Total order that worked:

### Phase 0 — Infrastructure

```bash
# Option A: push to cka-2026-study → GHA applies dev + obs
# Option B: local
cd Kubernetes/KubeADM-Day/kubeadm-on-ec2/dev && terraform apply -var-file=dev.tfvars
cd ../obs && terraform apply -var-file=obs.tfvars
```

### Phase 1 — VPC peering + routes (manual, §4)

### Phase 2 — kubeadm on all nodes

```bash
# Copy scripts (from laptop)
bash Kubernetes/KubeADM-Day/scripts/copy-scripts-to-nodes.sh dev
bash Kubernetes/KubeADM-Day/scripts/copy-scripts-to-nodes.sh obs

# On each master
sudo bash ~/prep-node-master.sh

# On each worker (after saving join command from master)
export JOIN_CMD='kubeadm join 10.x.x.x:6443 --token ... --discovery-token-ca-cert-hash sha256:...'
sudo -E bash ~/prep-node-worker.sh
```

**CNI:** Flannel with `--pod-network-cidr=10.244.0.0/16` (applied by prep-node-master.sh).

**Kubeconfig fix:** Scripts use `~/.kube/config` for ubuntu user, not only `/etc/kubernetes/admin.conf`.

### Phase 3 — obs observability stack

On **obs-master01**:

```bash
git clone https://github.com/htpractice/ht-study.git && cd ht-study
bash Kubernetes/KubeADM-Day/scripts/install-obs-stack.sh
```

Installs: Prometheus, Grafana, Loki+Promtail, Jaeger, OTel Collector, Argo CD.

**Grafana:** admin / `cka-lab`  
**Argo CD:** `kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d`

### Phase 4 — Argo CD multi-cluster

1. Copy dev kubeconfig to obs: `~/.kube/dev-config`
2. Register dev cluster in Argo CD UI (Settings → Clusters) — server URL uses dev **private IP** `:6443`
3. Apply Application:

```yaml
# Kubernetes/CICD-Day/argocd/application-order-api-kubeadm.yaml
destination:
  name: dev          # registered cluster name
  namespace: order-api
source:
  path: Kubernetes/CICD-Day/helm/order-api
  helm:
    valueFiles: [values-kubeadm.yaml]
syncPolicy:
  automated:
    selfHeal: true   # manual kubectl patches get reverted!
```

4. Create `dockerhub-creds` secret in dev `order-api` namespace for private pulls

### Phase 5 — dev metrics (for multicluster Grafana)

On **dev-master01**:

```bash
bash Kubernetes/KubeADM-Day/scripts/install-dev-metrics.sh
# outputs: KSM at <master-ip>:30301
```

### Phase 6 — obs multicluster Prometheus

On **obs-master01** (requires `~/.kube/dev-config`):

```bash
DEV_TARGET=10.110.100.184:30301 bash Kubernetes/KubeADM-Day/scripts/configure-obs-multicluster.sh
```

### Phase 7 — dev logs to obs Loki

On **obs** — upgrade Loki with NodePort:

```bash
helm upgrade loki grafana/loki-stack -n observability \
  -f Kubernetes/KubeADM-Day/manifests/obs/loki-stack-values.yaml
```

On **dev**:

```bash
LOKI_TARGET=10.210.100.57:30100 bash Kubernetes/KubeADM-Day/scripts/install-dev-promtail.sh
```

### Phase 8 — OTEL traces (GitOps)

Committed in `values-kubeadm.yaml` + deployment template. Argo sync deploys:

```yaml
otel:
  enabled: true
  exporterOtlpEndpoint: http://10.210.100.57:30317
```

Re-apply obs otel-collector for NodePort:

```bash
kubectl apply -f Kubernetes/Logs\&Monitoring-Day/manifests/otel-collector.yaml
```

---

## 8. GitOps — order-api on dev via Argo on obs

### Helm chart

```
Kubernetes/CICD-Day/helm/order-api/
├── Chart.yaml
├── values.yaml              # kind/EKS defaults
├── values-kubeadm.yaml      # lab overrides
└── templates/
    ├── namespace.yaml
    ├── deployment.yaml
    └── service.yaml
```

### values-kubeadm.yaml (key settings)

| Key | Value |
|-----|-------|
| `replicaCount` | 3 |
| `service.type` | NodePort |
| `service.nodePort` | 30080 |
| `image.repository` | hthaware2508/order-api-lab |
| `image.tag` | v1 (amd64 — rebuilt on EC2) |
| `image.pullSecrets` | dockerhub-creds |
| `otel.enabled` | true |
| `otel.exporterOtlpEndpoint` | http://10.210.100.57:30317 |

### Image build (on dev master — amd64)

```bash
cd Kubernetes/Logs\&Monitoring-Day/APP
sudo docker build -t hthaware2508/order-api-lab:v1 .
sudo docker login
sudo docker push hthaware2508/order-api-lab:v1
```

**Gotcha:** Pre-built image was arm64-only → `ImagePullBackOff` / exec format error on amd64 EC2.

---

## 9. Observability stack

### obs components

| Component | Namespace | Install method |
|-----------|-----------|----------------|
| Prometheus | observability | Helm `prometheus-community/prometheus` |
| Grafana | observability | Helm `grafana/grafana` (separate — not bundled in prometheus chart v29+) |
| Loki + Promtail | observability | Helm `grafana/loki-stack` |
| Jaeger | observability | `Logs&Monitoring-Day/manifests/jaeger.yaml` |
| OTel Collector | observability | `Logs&Monitoring-Day/manifests/otel-collector.yaml` |
| Argo CD | argocd | upstream install manifest |

### Grafana datasources (`manifests/obs/grafana-values.yaml`)

| Name | URL |
|------|-----|
| Prometheus | http://prometheus-server |
| Loki | http://loki:3100 |
| Jaeger | http://jaeger:16686 |

### dev agents (minimal)

| Agent | Port | Scraped/pushed by |
|-------|------|-------------------|
| kube-state-metrics | NodePort 30301 | obs Prometheus |
| node-exporter | hostNetwork 9100 | obs Prometheus |
| Promtail | — | pushes to obs Loki :30100 |

---

## 10. Cross-cluster data flows (NodePorts)

| Data | Source | Destination | NodePort | Config file |
|------|--------|-------------|----------|-------------|
| App HTTP | curl → dev worker | order-api | 30080 | values-kubeadm.yaml |
| KSM metrics | dev master | obs Prometheus | 30301 | install-dev-metrics.sh |
| Node metrics | dev all nodes | obs Prometheus | 9100 | configure-obs-multicluster.sh |
| OTLP traces | dev order-api pods | obs OTel | 30317 | values-kubeadm.yaml + otel-collector.yaml |
| Logs | dev Promtail | obs Loki | 30100 | install-dev-promtail.sh |

---

## 11. Verification commands

### Cluster health

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

### order-api

```bash
curl http://10.110.100.184:30080/health
curl -X POST http://10.110.100.184:30080/order \
  -H 'Content-Type: application/json' -d '{"item":"test","qty":1}'
kubectl get pods,svc,endpoints -n order-api
```

### Prometheus multicluster (obs)

```bash
kubectl port-forward -n observability svc/prometheus-server 9090:80 &
curl -s 'http://127.0.0.1:9090/api/v1/query?query=count%20by%20(cluster%2Cinstance)%20(up%7Bjob%3D%22node-exporter%22%7D)' | python3 -m json.tool
# Expect: 4 dev + 4 obs instances

curl -s 'http://127.0.0.1:9090/api/v1/label/cluster/values' | python3 -m json.tool
# Expect: ["dev","obs"]
```

Or run: `DEV_TARGET=10.110.100.184:30301 bash scripts/diagnose-multicluster.sh`

### Jaeger

```bash
kubectl port-forward -n observability svc/jaeger 16686:16686
# UI → service: order-api
```

### Loki

```logql
{namespace="order-api", cluster="dev"}
{namespace="order-api", cluster="dev"} |= "order_created"
```

### Argo CD

```bash
kubectl get applications -n argocd
argocd app get order-api   # if CLI configured
```

---

## 12. Grafana dashboards & queries

| Dashboard ID | Purpose | Requires |
|--------------|---------|----------|
| **15757** | K8s Global View | `cluster` label on metrics |
| **15760** | K8s Namespaces View | `cluster` label, kube-state-metrics |
| **1860** | Node Exporter Full | `job="node-exporter"` (not dev-node-exporter) |
| **6417** | K8s pod monitoring | kube-state-metrics (single-cluster kind lab) |

### PromQL samples

```promql
# Multicluster nodes
count by (cluster, instance) (up{job="node-exporter"})

# order-api request rate
rate(http_requests_total{namespace="order-api"}[5m])

# 503 errors
rate(http_requests_total{namespace="order-api",status="503"}[5m])
```

### LogQL samples

```logql
{namespace="order-api", cluster="dev"}
{namespace="order-api", cluster="dev"} |= "ERROR"
{namespace="order-api", cluster="dev"} | json | trace_id != ""
```

---

## 13. Troubleshooting encyclopedia

> **Full YAML/Helm details:** [observability-yaml-runbook.md](observability-yaml-runbook.md)  
> **Full SG details:** [security-groups-runbook.md](security-groups-runbook.md)

Every issue hit during the 11-hour build:

| # | Symptom | Root cause | Fix |
|---|---------|------------|-----|
| 1 | Pods pending, network not ready | CNI not installed / wrong pod CIDR | Flannel + `10.244.0.0/16` |
| 2 | Calico BIRD crash loop | Wrong CNI for lab | Switch to Flannel |
| 3 | Cross-node pod traffic fails | SG UDP 8472 only `/24` not `/16` | Open 8472 to full VPC CIDR |
| 4 | `localhost:8080 refused` kubectl | No kubeconfig | Copy admin.conf to `~/.kube/config` |
| 5 | Argo can't reach dev | Peering routes / SG 6443 | Peering + dev CP SG from obs CIDR |
| 6 | ImagePullBackOff order-api | arm64 image on amd64 EC2 | Rebuild + push amd64 on dev master |
| 7 | Grafana bundled in prometheus chart | Chart v29 removed Grafana | Separate `grafana/grafana` Helm install |
| 8 | Loki 404 on `/` | Normal — no handler on root | Use `/ready` or Explore; datasource URL `http://loki:3100` |
| 9 | Grafana "can't reach Loki" | Save & test false negative | Explore works; use Server access mode |
| 10 | Dashboard 6417 empty | No kube-state-metrics | Enable KSM or use 15757/15760 |
| 11 | Multicluster dropdown empty | `external_labels` ≠ stored `cluster` label | Scrape **relabel** `cluster: dev/obs` |
| 12 | ServiceMonitor CRD errors on dev | Full Prometheus chart on plain kubeadm | dev: KSM + node-exporter only (no Prometheus server) |
| 13 | `extraScrapeConfigs` ignored | Chart v29 moved to root `scrapeConfigs` map | Use `configure-obs-multicluster.sh` Python generator |
| 14 | `dev targets: 0` | Wrong YAML path / chart key | scrapeConfigs map + `job_name: node-exporter` |
| 15 | Node exporter dashboard obs-only | Job name = map key (`dev-node-exporter`) | Explicit `job_name: node-exporter` in scrape config |
| 16 | Jaeger empty | OTEL env missing + collector not NodePort | GitOps OTEL vars + otel-collector NodePort 30317 |
| 17 | Argo reverts manual kubectl patch | `selfHeal: true` | Change git or disable selfHeal |
| 18 | Loki `{namespace="order-api"}` empty | Promtail on obs only — app on dev | dev Promtail → obs Loki :30100 |
| 19 | prep-node-master env vars lost | Missing `export` on vars | Fixed in prep-node-master.sh (local, optional push) |

---

## 14. Interview stories earned

1. **Three-cluster mental model:** app vs obs vs prod — why split control planes
2. **VPC peering ≠ connectivity alone:** routes + SGs + DNS
3. **Flannel VXLAN:** UDP 8472 must span full VPC CIDR
4. **GitOps selfHeal:** git wins over manual drift
5. **Prometheus chart migration:** scrapeConfigs map keys become job_name
6. **`external_labels` vs relabel:** only relabel tags stored series for queries
7. **Cross-cluster observability:** agents on app cluster, platform on obs — NodePort bridge
8. **Incident triage order:** dashboard (symptom) → kubectl (infra) → logs (why) → traces (chain)
9. **Multi-arch containers:** always verify `docker buildx` / platform on EC2 amd64
10. **Loki 404 on /** is not down — check API paths

---

## 15. Pre-teardown capture

Run **before** destroying infrastructure:

```bash
cd Kubernetes/KubeADM-Day/scripts
bash capture-lab-aws-state.sh
```

Manual additions worth saving:

```bash
# Terraform outputs
cd ../kubeadm-on-ec2/dev && terraform output > ~/lab-dev-outputs.txt
cd ../obs && terraform output > ~/lab-obs-outputs.txt

# Cluster state (from masters)
kubectl get nodes,pods,svc -A -o wide > ~/lab-obs-k8s.txt      # on obs
kubectl --kubeconfig ~/.kube/dev-config get all -A > ~/lab-dev-k8s.txt  # on obs

# Argo apps
kubectl get applications -n argocd -o yaml > ~/lab-argocd-apps.yaml

# Prometheus targets
kubectl port-forward -n observability svc/prometheus-server 9090:80 &
curl -s localhost:9090/api/v1/targets > ~/lab-prom-targets.json

# Grafana dashboards (export JSON from UI if customized)
```

---

## 16. Teardown

**Order:** dev app first → obs → peering → verify empty

```bash
# GitHub Actions (recommended)
# .github/workflows/kubeadm-terraform-destroy.yaml
# workflow_dispatch → environment: dev → confirm: destroy → approve
# repeat for obs

# Or local
cd Kubernetes/KubeADM-Day/kubeadm-on-ec2/dev
terraform destroy -var-file=dev.tfvars

cd ../obs
terraform destroy -var-file=obs.tfvars

# Manual: delete VPC peering pcx-0a20139fd655d1170 if still exists
```

**Keep:** S3 state buckets (versioned), Secrets Manager keys, this doc, git branch.

---

## 17. File index

### Scripts (`Kubernetes/KubeADM-Day/scripts/`)

| File | Run on |
|------|--------|
| `prep-node-master.sh` | Each master |
| `prep-node-worker.sh` | Each worker |
| `copy-scripts-to-nodes.sh` | Laptop |
| `install-obs-stack.sh` | obs master |
| `install-dev-metrics.sh` | dev master |
| `install-dev-promtail.sh` | dev master |
| `configure-obs-multicluster.sh` | obs master |
| `diagnose-multicluster.sh` | obs master |
| `capture-lab-aws-state.sh` | Laptop (pre-teardown) |
| `s3-backend.sh` | One-time S3 setup |

### Manifests (`Kubernetes/KubeADM-Day/manifests/obs/`)

| File | Purpose |
|------|---------|
| `prometheus-values.yaml` | Base obs Prometheus (pre-multicluster) |
| `grafana-values.yaml` | Grafana + datasources |
| `loki-stack-values.yaml` | Loki NodePort 30100 + obs Promtail |

### Helm + Argo (`Kubernetes/CICD-Day/`)

| File | Purpose |
|------|---------|
| `helm/order-api/values-kubeadm.yaml` | Lab values |
| `helm/order-api/templates/deployment.yaml` | OTEL env vars |
| `argocd/application-order-api-kubeadm.yaml` | GitOps app |

### App source (`Kubernetes/Logs&Monitoring-Day/APP/`)

| File | Purpose |
|------|---------|
| `app.py` | Flask + Prometheus + OTEL traces |
| `Dockerfile` | Container build |

### OTEL/Jaeger manifests

| File | Purpose |
|------|---------|
| `Logs&Monitoring-Day/manifests/otel-collector.yaml` | NodePort 30317 |
| `Logs&Monitoring-Day/manifests/jaeger.yaml` | Trace backend |

---

## 18. Git commit timeline

Key commits on `cka-2026-study` (newest first):

| Commit | Summary |
|--------|---------|
| f1f1dc8 | Loki SG 30100 on obs worker |
| dddd4fd | dev Promtail → obs Loki |
| 3dae4f0 | Explicit job_name for node-exporter |
| 5de46c6 | Unify node-exporter job label |
| 0b84cb6 | OTEL GitOps for Jaeger |
| 2b91e1d | scrapeConfigs map (chart v29) — multicluster fix |
| 82cfb72 | dev metrics without full Prometheus chart |
| 97aada2 | cluster label via scrape relabel |
| b73a102 | Argo → dev, 3 replicas |
| 9282d3d | Flannel UDP 8472 in SGs |
| 829bd55 | Separate Grafana Helm chart |
| 17de283 | install-obs-stack.sh |
| 32d62cc | obs kubeadm stack + GHA dev/obs |
| 1eb8ed9 | dev EC2 Terraform + bootstrap scripts |

---

## Quick reference card

```bash
# SSH
ssh -i dev/private_key.pem ubuntu@18.236.111.76    # dev master
ssh -i obs/private_key.pem ubuntu@54.218.254.122   # obs master (or Secrets Manager)

# App
curl http://10.110.100.184:30080/health

# UIs (from laptop via SSH tunnel on obs)
kubectl port-forward -n observability svc/grafana 3000:80
kubectl port-forward -n observability svc/jaeger 16686:16686
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Multicluster refresh
DEV_TARGET=10.110.100.184:30301 bash configure-obs-multicluster.sh
LOKI_TARGET=10.210.100.57:30100 bash install-dev-promtail.sh
```

---

*Lab built for CKA / platform SRE practice — kubeadm + GitOps + full observability stack on AWS.*
