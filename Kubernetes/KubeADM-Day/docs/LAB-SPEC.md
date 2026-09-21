# Kubeadm E2E Lab — Canonical Spec

**Purpose:** Single source of truth for AI agents and operators to **reproduce** or **guide setup** of the dev+obs kubeadm lab on AWS.

**Branch:** `cka-2026-study` · **Repo:** `htpractice/ht-study`  
**Region:** `us-west-2` · **K8s:** v1.35.7 · **CNI:** Flannel (`10.244.0.0/16`)

**Deep references (do not duplicate — link out):**
- [security-groups-runbook.md](security-groups-runbook.md) — all SG rules, console vs Terraform
- [observability-yaml-runbook.md](observability-yaml-runbook.md) — Prometheus/Grafana/Loki/Jaeger Helm traps
- [e2e-lab-complete-runbook.md](e2e-lab-complete-runbook.md) — narrative, AWS snapshot, troubleshooting table

---

## 1. Target architecture

```
dev VPC 10.110.0.0/16          obs VPC 10.210.0.0/16
├── 1 CP + 3 workers           ├── 1 CP + 3 workers
├── order-api (Argo target)    ├── Argo CD (control plane)
├── KSM :30301 + node-exp :9100├── Prometheus + Grafana
├── Promtail → obs Loki        ├── Loki :30100 + Jaeger + OTel :30317
└── OTEL → obs :30317          └── scrapes dev metrics over peering
         └──── VPC peering pcx (manual) + routes on all RTs ────┘
```

| Cluster | Role | Key IPs (lab instance) |
|---------|------|------------------------|
| dev | app | master `10.110.100.184`, workers `.179/.224/.30` |
| obs | observability + GitOps | master `10.210.100.57` |

Replace IPs after each Terraform apply — use `terraform output` and `capture-lab-aws-state.sh`.

---

## 2. Prerequisites

| Requirement | Detail |
|-------------|--------|
| AWS account | S3 state buckets: `cka-2026-study-terraform-state-{dev,obs,prod}` |
| GitHub | Workflow `.github/workflows/kubeadm-terraform.yaml` on `cka-2026-study` |
| Secrets | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`; GitHub env approvals: dev, obs |
| SSH | dev: `kubeadm-on-ec2/dev/private_key.pem`; obs: Secrets Manager `kubeadm/obs/ssh-private-key` |
| Laptop | `kubectl`, `helm`, `aws`, `gh` optional; operator IP in `*.tfvars` `allow_ssh_from_cidr_blocks` |

---

## 3. Setup sequence (strict order)

Agents MUST follow this order. Do not skip peering or SG verification.

### Phase 0 — Infrastructure

```bash
# GHA: push to cka-2026-study under kubeadm-on-ec2/** OR local:
cd Kubernetes/KubeADM-Day/kubeadm-on-ec2/dev && terraform apply -var-file=dev.tfvars
cd ../obs && terraform apply -var-file=obs.tfvars
```

### Phase 1 — VPC peering (manual, not in TF)

1. Create peering obs ↔ dev; accept; status **active**
2. Enable DNS resolution both sides
3. Add routes on **all** route tables (public + private):
   - dev → `10.210.0.0/16` via peering
   - obs → `10.110.0.0/16` via peering

### Phase 2 — kubeadm bootstrap (both clusters)

```bash
bash Kubernetes/KubeADM-Day/scripts/copy-scripts-to-nodes.sh dev
bash Kubernetes/KubeADM-Day/scripts/copy-scripts-to-nodes.sh obs

# On each master:
sudo bash ~/prep-node-master.sh

# On each worker (JOIN_CMD from master init output):
export JOIN_CMD='kubeadm join <CP_PRIVATE_IP>:6443 ...'
sudo -E bash ~/prep-node-worker.sh
```

**Gates:** `kubectl get nodes` → 4 Ready; `kubectl get pods -n kube-flannel` → Running.

### Phase 3 — obs platform

On **obs-master**:

```bash
git clone -b cka-2026-study https://github.com/htpractice/ht-study.git
bash ht-study/Kubernetes/KubeADM-Day/scripts/install-obs-stack.sh

# After stack up — Loki NodePort (if not in fresh install-obs-stack curl values):
helm upgrade loki grafana/loki-stack -n observability \
  -f ht-study/Kubernetes/KubeADM-Day/manifests/obs/loki-stack-values.yaml

kubectl apply -f ht-study/Kubernetes/Logs\&Monitoring-Day/manifests/otel-collector.yaml
```

**Gates:** `kubectl get pods -n observability` → prometheus-server, grafana, loki-0, jaeger, otel-collector Running.

### Phase 4 — Argo CD multi-cluster

On **obs-master**:

1. Copy dev kubeconfig → `~/.kube/dev-config` (server URL = dev CP **private** IP `:6443`)
2. Argo UI → Settings → Clusters → add cluster name **`dev`**
3. Create Application from `Kubernetes/CICD-Day/argocd/application-order-api-kubeadm.yaml`
4. On **dev**: create `dockerhub-creds` in `order-api` namespace
5. Build/push **amd64** image on dev master if ImagePullBackOff:

```bash
cd ht-study/Kubernetes/Logs\&Monitoring-Day/APP
sudo docker build -t hthaware2508/order-api-lab:v1 .
sudo docker login && sudo docker push hthaware2508/order-api-lab:v1
```

**Gates:** `kubectl --kubeconfig ~/.kube/dev-config get pods -n order-api` → 3/3 Ready; `curl http://<dev-worker-ip>:30080/health`.

### Phase 5 — Multicluster metrics

On **dev-master**:

```bash
bash ht-study/Kubernetes/KubeADM-Day/scripts/install-dev-metrics.sh
# note master IP for DEV_TARGET
```

On **obs-master** (requires `~/.kube/dev-config`):

```bash
DEV_TARGET=10.110.100.184:30301 bash ht-study/Kubernetes/KubeADM-Day/scripts/configure-obs-multicluster.sh
```

**Gates:** script ends with `dev targets: 5`, `cluster labels: ['dev','obs']`, 8× `node-exporter up`.

### Phase 6 — Cross-cluster logs

On **dev-master**:

```bash
LOKI_TARGET=10.210.100.57:30100 bash ht-study/Kubernetes/KubeADM-Day/scripts/install-dev-promtail.sh
```

**Gates:** Grafana Explore `{namespace="order-api", cluster="dev"}` returns JSON logs.

### Phase 7 — Traces (GitOps)

Ensure git has OTEL in `values-kubeadm.yaml` + deployment template. Argo sync `order-api`.

**Gates:** `kubectl exec -n order-api deploy/order-api -- env | grep OTEL`; Jaeger UI service `order-api` after POST `/order` traffic.

---

## 4. Cross-VPC port matrix (SG bouncer)

| Port | Direction | Service |
|------|-----------|---------|
| 6443 | obs → dev CP | Argo → dev API |
| 9100 | obs → dev all nodes | node-exporter scrape |
| 30301 | obs → dev master | kube-state-metrics |
| 30317 | dev → obs | OTel OTLP |
| 30100 | dev → obs | Loki push |
| 8472 UDP | within each VPC `/16` | Flannel VXLAN |

Verify before debugging app config:

```bash
# from obs: nc -vz 10.110.100.184 9100 30301 6443
# from dev: nc -vz 10.210.100.57 30317 30100
```

Full SG tables: [security-groups-runbook.md](security-groups-runbook.md).

---

## 5. Key config files (do not guess)

| Component | Path |
|-----------|------|
| Terraform dev | `kubeadm-on-ec2/dev/` + `dev.tfvars` |
| Terraform obs | `kubeadm-on-ec2/obs/` + `obs.tfvars` |
| obs Prometheus base | `manifests/obs/prometheus-values.yaml` |
| Multicluster Prometheus | generated by `scripts/configure-obs-multicluster.sh` |
| Grafana datasources | `manifests/obs/grafana-values.yaml` |
| Loki NodePort | `manifests/obs/loki-stack-values.yaml` |
| OTel NodePort | `Logs&Monitoring-Day/manifests/otel-collector.yaml` |
| order-api Helm | `CICD-Day/helm/order-api/values-kubeadm.yaml` |
| Argo Application | `CICD-Day/argocd/application-order-api-kubeadm.yaml` |

---

## 6. Verification checklist (lab complete)

- [ ] 8 EC2 running (4 dev + 4 obs)
- [ ] Peering active; routes on all RTs
- [ ] 4 nodes Ready per cluster
- [ ] order-api 3 replicas on dev; NodePort 30080
- [ ] Argo `order-api` Synced/Healthy
- [ ] Prometheus: `count by (cluster) (kube_node_info)` → dev + obs
- [ ] Prometheus: `count by (cluster,instance) (up{job="node-exporter"})` → 4+4
- [ ] Grafana dashboards 15757/15760 show cluster dropdown; 1860 shows 8 nodes
- [ ] Loki: `{namespace="order-api", cluster="dev"}`
- [ ] Jaeger: service `order-api` traces after POST `/order`

Diagnostic script: `DEV_TARGET=<dev-ip>:30301 bash scripts/diagnose-multicluster.sh`

---

## 7. Agent troubleshooting rules

When user reports empty dashboard / no targets / no logs:

1. **Network first:** `nc -vz` cross-VPC ports (§4) — not Grafana config
2. **Prometheus targets API:** `curl localhost:9090/api/v1/targets` on obs — count dev jobs
3. **Label issues:** stored `cluster` label requires **scrape relabel**, not `external_labels`
4. **Chart v29:** use `scrapeConfigs` map + explicit `job_name: node-exporter`
5. **Loki empty for order-api:** dev Promtail must push to obs — obs Promtail alone is insufficient
6. **Jaeger empty:** OTEL env in git + otel-collector NodePort 30317 on obs — not in-cluster DNS from dev
7. **Argo drift:** `selfHeal: true` reverts manual kubectl — fix git

Full failure index: [e2e-lab-complete-runbook.md](e2e-lab-complete-runbook.md) §13.

---

## 8. Teardown

```bash
# GitHub Actions: kubeadm-terraform-destroy.yaml → dev, then obs → confirm "destroy"
# Manual: delete VPC peering after instances gone
bash Kubernetes/KubeADM-Day/scripts/capture-lab-aws-state.sh ~/lab-aws-snapshot-$(date +%Y%m%d).txt
```

---

## 9. Known non-blockers (ignore unless persistent)

- `loki-0` 0/1 for 1–2 min after install
- `argocd-dex-server` restart once
- Loki `curl http://loki:3100` → 404 (normal)
- Grafana Loki "Save & test" red while Explore works

---

## 10. Appendix — dead ends (do not retry)

| Attempt | Why it failed | Use instead |
|---------|---------------|-------------|
| Prometheus federation dev:30300 | dev has no Prometheus server | Direct scrape KSM:30301 + node-exp:9100 |
| `server.external_labels.cluster` | Does not tag local TSDB | scrape `metric_relabel_configs` |
| `extraScrapeConfigs` under `server:` on chart v29 | Ignored / wrong path | Root `scrapeConfigs` map |
| Full Prometheus chart on dev | ServiceMonitor CRD missing | `install-dev-metrics.sh` only |
| `otel-collector.obs.svc.cluster.local` from dev pods | DNS is cluster-local | NodePort 30317 on obs master IP |
| obs Promtail only for order-api logs | Promtail is node-local | dev Promtail → obs Loki |

---

*Spec version: 2026-08-10 — validated on live lab pcx-0a20139fd655d1170, account 725335002991.*
