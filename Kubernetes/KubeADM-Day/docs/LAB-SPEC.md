# LAB-SPEC — Kubeadm E2E (dev + obs)

**Canonical specification** to reproduce the CrowdStrike-style platform lab:  
Terraform → kubeadm → Argo GitOps → cross-cluster Prometheus/Grafana/Loki/Jaeger.

**Branch:** `cka-2026-study` · **Repo:** `htpractice/ht-study`  
**Use this file first** when setting up the lab or guiding a user.  
**Troubleshooting depth:** [security-groups-runbook.md](security-groups-runbook.md) · [observability-yaml-runbook.md](observability-yaml-runbook.md) · [e2e-lab-complete-runbook.md](e2e-lab-complete-runbook.md)

---

## For agents (Cursor / automation)

When asked to **set up**, **restore**, or **guide** this lab:

1. Read this entire spec before running commands.
2. Execute phases **in order** — do not skip peering/SG before observability.
3. After each phase, run the **gate** commands; if a gate fails, consult the linked runbook section before proceeding.
4. Replace all `<PLACEHOLDERS>` from Terraform outputs or user-provided IPs.
5. Never `kubectl apply` order-api to dev directly if Argo `selfHeal: true` — change git + sync.
6. Cross-cluster always uses **obs master private IP** + **NodePort** (not in-cluster DNS across VPCs).
7. Prometheus multicluster: always use `configure-obs-multicluster.sh` (scrapeConfigs map), not manual federation.

---

## Constants

| Key | Value |
|-----|-------|
| Region | `us-west-2` |
| dev VPC CIDR | `10.110.0.0/16` |
| obs VPC CIDR | `10.210.0.0/16` |
| Pod CIDR (both clusters) | `10.244.0.0/16` (Flannel) |
| K8s version | `v1.35.7` / package `1.35.7-1.1` |
| dev master hostname | `dev-k8s-m1` |
| obs master hostname | `obs-k8s-m1` |
| Git branch | `cka-2026-study` |

### NodePorts & ports (cross-VPC)

| Port | Direction | Service |
|------|-----------|---------|
| 6443 | obs → dev CP | Argo CD → dev API |
| 9100 | obs → dev nodes | node-exporter scrape |
| 30301 | obs → dev master | kube-state-metrics |
| 30317 | dev → obs | OTel OTLP gRPC |
| 30100 | dev → obs | Loki push |
| 30080 | external → dev | order-api HTTP |
| 8472/UDP | within each VPC `/16` | Flannel VXLAN |

### Placeholders (fill after Terraform / bootstrap)

```bash
DEV_MASTER_PRIVATE=<e.g. 10.110.100.184>
OBS_MASTER_PRIVATE=<e.g. 10.210.100.57>
DEV_MASTER_PUBLIC=<terraform output>
OBS_MASTER_PUBLIC=<terraform output>
PEERING_ID=<pcx-xxxxxxxx>
```

---

## Prerequisites

- [ ] AWS account + credentials (`infra-user` or equivalent)
- [ ] GitHub repo access; branch `cka-2026-study`
- [ ] GitHub secrets for GHA: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
- [ ] GitHub Environments with approval: `dev`, `obs`
- [ ] Operator laptop IP in `dev.tfvars` / `obs.tfvars` → `allow_ssh_from_cidr_blocks`
- [ ] Docker Hub creds for private pull (or public image)
- [ ] S3 state buckets (run `scripts/s3-backend.sh` once if missing)

---

## Phase 0 — Terraform (dev + obs)

**Path:** `Kubernetes/KubeADM-Day/kubeadm-on-ec2/{dev,obs}/`

**Option A — GHA:** Push to `cka-2026-study` under `kubeadm-on-ec2/**` → approve dev + obs applies.

**Option B — Local:**
```bash
cd kubeadm-on-ec2/dev && terraform init && terraform apply -var-file=dev.tfvars
cd ../obs && terraform init && terraform apply -var-file=obs.tfvars
```

**Gate:**
```bash
# 4 nodes each env from laptop
aws ec2 describe-instances --region us-west-2 \
  --filters "Name=tag:Environment,Values=dev" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].Tags[?Key==`Name`].Value'
# Expect: dev-k8s-m1, dev-k8s-w1, w2, w3 (same for obs)
```

**Outputs to save:** public IPs, SG IDs, `private_key.pem` (dev), Secrets Manager key (obs).

---

## Phase 1 — VPC peering (manual, required)

**Not in Terraform.** Create peering obs ↔ dev.

1. Create peering connection between dev VPC and obs VPC → `<PEERING_ID>`
2. Accept peering
3. Enable DNS resolution both sides
4. Add routes on **all** route tables (public + private):
   - dev → `10.210.0.0/16` via peering
   - obs → `10.110.0.0/16` via peering

**Gate (from obs master after Phase 2, or from any instance in peered VPC):**
```bash
ping -c 2 $DEV_MASTER_PRIVATE
```

**If fail:** [security-groups-runbook.md](security-groups-runbook.md) + check routes, not just peering status.

---

## Phase 2 — kubeadm bootstrap (both clusters)

**Scripts:** `Kubernetes/KubeADM-Day/scripts/`

```bash
# Laptop — copy scripts
bash scripts/copy-scripts-to-nodes.sh dev
bash scripts/copy-scripts-to-nodes.sh obs

# Each master
sudo bash ~/prep-node-master.sh

# Each worker (join cmd from master init output)
export JOIN_CMD='kubeadm join <CP_PRIVATE>:6443 --token ... --discovery-token-ca-cert-hash sha256:...'
sudo -E bash ~/prep-node-worker.sh
```

**CNI:** Flannel applied by `prep-node-master.sh` (`10.244.0.0/16`).

**Gate (each cluster):**
```bash
kubectl get nodes
# 4/4 Ready

kubectl get pods -n kube-flannel
# All Running
```

**Common failures:** wrong pod CIDR, Calico leftover, SG UDP 8472 not full `/16` → [e2e-lab-complete-runbook.md §13](e2e-lab-complete-runbook.md#13-troubleshooting-encyclopedia).

---

## Phase 3 — obs observability + Argo CD

**Run on obs master:**
```bash
git clone https://github.com/htpractice/ht-study.git && cd ht-study
git checkout cka-2026-study
bash Kubernetes/KubeADM-Day/scripts/install-obs-stack.sh
```

Installs: Prometheus, Grafana, Loki+Promtail, Jaeger, OTel Collector, Argo CD.

**Post-install — Loki NodePort (required for dev logs):**
```bash
helm upgrade loki grafana/loki-stack -n observability \
  -f Kubernetes/KubeADM-Day/manifests/obs/loki-stack-values.yaml
```

**OTel NodePort (required for dev traces):**
```bash
kubectl apply -f Kubernetes/Logs\&Monitoring-Day/manifests/otel-collector.yaml
```

**Gate:**
```bash
kubectl get pods -n observability
kubectl get pods -n argocd
# prometheus-server, grafana, loki-0, jaeger, otel-collector, argocd-server Running

kubectl get svc otel-collector -n observability -o jsonpath='{.spec.ports[?(@.name=="otlp-grpc")].nodePort}'
# 30317

kubectl get svc loki -n observability -o jsonpath='{.spec.ports[0].nodePort}'
# 30100
```

**Grafana:** admin / `cka-lab` — port-forward or SG :3000 from laptop.

---

## Phase 4 — Argo CD multi-cluster + order-api

1. Copy dev kubeconfig to obs: `~/.kube/dev-config`
2. Argo UI → Settings → Clusters → add dev (URL: `https://<DEV_MASTER_PRIVATE>:6443`)
3. Create docker secret on dev:
   ```bash
   kubectl create secret docker-registry dockerhub-creds -n order-api \
     --docker-username=... --docker-password=... --dry-run=client -o yaml | kubectl apply -f -
   ```
4. Apply Argo Application (on obs):
   ```yaml
   # Kubernetes/CICD-Day/argocd/application-order-api-kubeadm.yaml
   destination.name: dev
   helm.valueFiles: [values-kubeadm.yaml]
   ```
5. Build **amd64** image on dev master if needed:
   ```bash
   cd Kubernetes/Logs\&Monitoring-Day/APP
   sudo docker build -t hthaware2508/order-api-lab:v1 .
   sudo docker push hthaware2508/order-api-lab:v1
   ```

**Update** `values-kubeadm.yaml`:
```yaml
otel.exporterOtlpEndpoint: http://<OBS_MASTER_PRIVATE>:30317
```

**Gate:**
```bash
# on dev
kubectl get pods -n order-api
curl http://<DEV_MASTER_PRIVATE>:30080/health

kubectl exec -n order-api deploy/order-api -- env | grep OTEL
# OTEL_EXPORTER_OTLP_ENDPOINT=http://<OBS_MASTER_PRIVATE>:30317
```

---

## Phase 5 — dev metrics (for multicluster Grafana)

**Run on dev master:**
```bash
bash Kubernetes/KubeADM-Day/scripts/install-dev-metrics.sh
# Note master IP for DEV_TARGET
```

**Gate:**
```bash
curl -s http://<DEV_MASTER_PRIVATE>:30301/metrics | head -1
nc -vz <DEV_MASTER_PRIVATE> 9100
```

---

## Phase 6 — obs multicluster Prometheus

**Run on obs master** (requires `~/.kube/dev-config`):
```bash
DEV_TARGET=<DEV_MASTER_PRIVATE>:30301 \
  bash Kubernetes/KubeADM-Day/scripts/configure-obs-multicluster.sh
```

**Gate (end of script output):**
```
dev targets: 5
cluster labels: ['dev', 'obs']
node-exporter up by cluster: 4 dev + 4 obs
```

**If `dev targets: 0`:** [observability-yaml-runbook.md §3](observability-yaml-runbook.md#3-prometheus-chart-v29-scrapeconfigs-not-extrasrapeconfigs)

**Optional diagnose:**
```bash
DEV_TARGET=<DEV_MASTER_PRIVATE>:30301 \
  bash Kubernetes/KubeADM-Day/scripts/diagnose-multicluster.sh
```

---

## Phase 7 — dev logs → obs Loki

**Run on dev master:**
```bash
LOKI_TARGET=<OBS_MASTER_PRIVATE>:30100 \
  bash Kubernetes/KubeADM-Day/scripts/install-dev-promtail.sh
```

**Gate (Grafana Explore → Loki):**
```logql
{namespace="order-api", cluster="dev"}
```

---

## Phase 8 — End-to-end verification

| Pillar | Check |
|--------|-------|
| **Metrics** | Grafana Explore: `count by (cluster, instance) (up{job="node-exporter"})` → 8 |
| **K8s views** | Dashboards 15757/15760 — cluster dropdown dev + obs |
| **App** | `curl -X POST http://<DEV_MASTER>:30080/order -H 'Content-Type: application/json' -d '{"item":"x","qty":1}'` |
| **Traces** | Jaeger UI → service `order-api` |
| **Logs** | Loki `{namespace="order-api", cluster="dev"}` |
| **GitOps** | `kubectl get applications -n argocd` → Synced |

**Cross-VPC connectivity gates (run before blaming YAML):**
```bash
# obs → dev
nc -vz $DEV_MASTER_PRIVATE 6443 9100 30301
# dev → obs
nc -vz $OBS_MASTER_PRIVATE 30317 30100
```

---

## Security groups checklist

Before Phase 6–7, confirm [security-groups-runbook.md](security-groups-runbook.md) cross-VPC rules exist (Terraform and/or console):

- dev CP+worker: TCP 9100, 30301 (or 30300–30400) from `10.210.0.0/16`
- dev CP: TCP 6443 from `10.210.0.0/16`
- obs CP+worker: TCP 30100, 30317 (or 30000–35000) from `10.110.0.0/16`
- both: UDP 8472 from full VPC `/16`

---

## Teardown

1. Capture state: `bash scripts/capture-lab-aws-state.sh ~/lab-aws-snapshot.txt`
2. GHA: `.github/workflows/kubeadm-terraform-destroy.yaml` → `destroy` → dev, then obs
3. Delete VPC peering manually if orphaned

---

## File map (source of truth in git)

| Purpose | Path |
|---------|------|
| **This spec** | `docs/LAB-SPEC.md` |
| Terraform dev | `kubeadm-on-ec2/dev/` |
| Terraform obs | `kubeadm-on-ec2/obs/` |
| Bootstrap scripts | `scripts/prep-node-*.sh`, `copy-scripts-to-nodes.sh` |
| obs stack installer | `scripts/install-obs-stack.sh` |
| dev metrics | `scripts/install-dev-metrics.sh` |
| dev logs | `scripts/install-dev-promtail.sh` |
| multicluster prom | `scripts/configure-obs-multicluster.sh` |
| Helm app | `../../CICD-Day/helm/order-api/` |
| Argo app | `../../CICD-Day/argocd/application-order-api-kubeadm.yaml` |
| obs prom/grafana/loki values | `manifests/obs/*.yaml` |
| OTEL/Jaeger manifests | `../../Logs&Monitoring-Day/manifests/` |

---

## Known failure index (12-hour lab)

| # | Symptom | Doc |
|---|---------|-----|
| 1 | Nodes NotReady / CNI | e2e §13 #1–2 |
| 2 | Cross-node pods fail | SG runbook — UDP 8472 `/16` |
| 3 | Argo can't sync dev | SG 6443 + peering |
| 4 | ImagePullBackOff exec format | yaml §12 — amd64 rebuild |
| 5 | No Grafana pod | yaml §6 |
| 6 | cluster dropdown empty | yaml §2 — relabel not external_labels |
| 7 | dev targets: 0 | yaml §3 — scrapeConfigs map |
| 8 | node exporter dashboard wrong | yaml §4 — job_name |
| 9 | ServiceMonitor CRD error | yaml §5 |
| 10 | Loki empty for order-api | yaml §8 — dev Promtail |
| 11 | Jaeger empty | yaml §9 — OTEL + NodePort 30317 |
| 12 | kubectl patch reverted | yaml §11 — Argo selfHeal |

---

*Spec version: 2026-08-10 — validated on live AWS dev+obs cluster.*
