# Security Groups — Complete Reference (Lab Truth)

**This is the main reference for what made cross-cluster observability work.**

Sources: live AWS snapshot (`lab-aws-snapshot-20260810.txt`), console edits during the 11-hour lab, and Terraform in `kubeadm-on-ec2/{dev,obs}/networking.tf`.

**Mental model:** VPC peering = attachment · routes = map · **security groups = bouncer**. All three required.

---

## SG inventory (live)

| SG ID | Environment | Role | Attached to |
|-------|-------------|------|-------------|
| `sg-08c4616d57cc9af82` | dev | control-plane | dev-k8s-m1 |
| `sg-026a5d2b7c69cdbdc` | dev | worker | dev-k8s-w1, w2, w3 |
| `sg-04f339552dae38dd5` | obs | control-plane | obs-k8s-m1 |
| `sg-09881b6ca704e5ba9` | obs | worker | obs-k8s-w1, w2, w3 |

---

## Cross-VPC traffic map (the whole lab in one table)

| Port | Proto | Direction | Service | Why |
|------|-------|-----------|---------|-----|
| **6443** | TCP | obs → dev CP | Kubernetes API | Argo CD on obs manages dev cluster |
| **9100** | TCP | obs → dev all nodes | node-exporter | Prometheus multicluster node metrics |
| **30301** | TCP | obs → dev master | kube-state-metrics | Prometheus multicluster K8s object metrics |
| **30300–30400** | TCP | obs → dev | NodePort range | Console rule; covers 30301 + legacy federation attempts |
| **30317** | TCP | dev → obs | OTel Collector | order-api OTLP traces → Jaeger |
| **30100** | TCP | dev → obs | Loki NodePort | dev Promtail log push |
| **30000–35000** | TCP | dev → obs | NodePort range | Console rule; covers 30100 + 30317 |
| **8472** | UDP | within VPC `/16` | Flannel VXLAN | Pod cross-node traffic (must be full VPC CIDR) |
| **30080** | TCP | anywhere in dev VPC | order-api NodePort | App access (same-VPC NodePort rule) |

---

## dev control-plane SG (`sg-08c4616d57cc9af82`)

| Port | Proto | Source | Description | Terraform | Console |
|------|-------|--------|-------------|-----------|---------|
| 6443 | TCP | `10.110.0.0/16` | K8s API (in-VPC) | yes | yes |
| 6443 | TCP | `10.210.0.0/16` | Allow from OBS VPC (Argo) | yes (`6443-tcp-from-obs`) | yes (duplicate rule) |
| 9100 | TCP | `10.210.0.0/16` | node-exporter scrape | yes | yes |
| 30300–30400 | TCP | `10.210.0.0/16` | Prometheus NodePort federation | **no** | **yes (manual)** |
| 30301 | TCP | `10.210.0.0/16` | kube-state-metrics | yes | covered by range |
| 8472 | UDP | `10.110.0.0/16` | Flannel VXLAN | yes | yes |
| 2379–2380 | TCP | `10.110.0.0/16` | etcd | yes | yes |
| 10248–10259 | TCP | `10.110.0.0/16` | kubelet | yes | yes |
| 179 | TCP | `10.110.0.0/16` | BGP (legacy label) | yes | yes |
| 22 | TCP | `223.233.85.32/32` | SSH | yes | yes |

---

## dev worker SG (`sg-026a5d2b7c69cdbdc`)

| Port | Proto | Source | Description | Terraform | Console |
|------|-------|--------|-------------|-----------|---------|
| 9100 | TCP | `10.210.0.0/16` | node-exporter scrape | yes | yes |
| 30300–30400 | TCP | `10.210.0.0/16` | Prometheus from OBS VPC | **no** | **yes (manual)** |
| 30301 | TCP | `10.210.0.0/16` | kube-state-metrics | yes | covered by range |
| 8472 | UDP | `10.110.0.0/16` | Flannel VXLAN | yes | yes |
| 30000–32767 | TCP/UDP | `10.110.0.0/16` | NodePort (order-api 30080) | yes | yes |
| 10248–10259 | TCP | `10.110.0.0/16` | kubelet | yes | yes |
| 179 | TCP | `10.110.0.0/16` | BGP | yes | yes |
| 22 | TCP | `223.233.85.32/32` | SSH | yes | yes |

**Critical fix during lab:** dev worker SG was **missing UDP 8472 entirely** at one point → pods on different subnets could not talk. Fixed manually, then codified in Terraform (`9282d3d`).

---

## obs control-plane SG (`sg-04f339552dae38dd5`)

| Port | Proto | Source | Description | Terraform | Console |
|------|-------|--------|-------------|-----------|---------|
| 30000–35000 | TCP | `10.110.0.0/16` | otel exporter (broad) | **no** (TF uses 30317+30100) | **yes (manual)** |
| 30317 | TCP | `10.110.0.0/16` | OTLP gRPC | yes | covered by range |
| 30100 | TCP | `10.110.0.0/16` | Loki push | yes | covered by range |
| 9100 | TCP | `10.210.0.0/16` | node-exporter (in-VPC) | yes | yes |
| 6443 | TCP | `10.210.0.0/16` | K8s API | yes | yes |
| 8472/VXLAN | UDP | `10.210.0.0/16` | Flannel (broad 0-65535 in console) | yes (8472 only) | broader in live |
| 3000 | TCP | `223.233.85.32/32` | Grafana access | **no** | **yes (manual)** |
| 8080 | TCP | `223.233.85.32/32` | Argo CD UI | **no** | **yes (manual)** |
| 22 | TCP | `223.233.85.32/32` | SSH | yes | yes |

---

## obs worker SG (`sg-09881b6ca704e5ba9`)

| Port | Proto | Source | Description | Terraform | Console |
|------|-------|--------|-------------|-----------|---------|
| 30000–35000 | TCP | `10.110.0.0/16` | otel exporter (broad) | **no** (TF uses 30317+30100) | **yes (manual)** |
| 30317 | TCP | `10.110.0.0/16` | OTLP | yes | covered by range |
| 30100 | TCP | `10.110.0.0/16` | Loki | yes | covered by range |
| 3100 | TCP | `10.210.0.0/16` | loki ClusterIP (in-VPC) | **no** | **yes (manual)** |
| 9100 | TCP | `10.210.0.0/16` | node-exporter | yes | yes |
| 30000–32767 | TCP/UDP | `10.210.0.0/16` | NodePort (in-VPC) | yes | yes |
| 8472/VXLAN | UDP | `10.210.0.0/16` | cross-node pods | yes / broad console | yes |
| 22 | TCP | `223.233.85.32/32` | SSH | yes | yes |

---

## Terraform vs console drift

Rules that exist **live in AWS** but differ from current Terraform:

| Rule | Where live | Terraform status | Risk on next `terraform apply` |
|------|------------|------------------|--------------------------------|
| dev 30300–30400 from obs | dev CP + worker | not in TF | **may be removed** unless added to TF |
| obs 30000–35000 from dev | obs CP + worker | TF has exact 30100/30317 | apply may **narrow** rules (still works if precise ports kept) |
| obs Grafana :3000, Argo :8080 | obs CP | not in TF | **may be removed** — use SSH tunnel instead |
| dev CP duplicate 6443 from obs | console label | TF has dedicated rule | harmless duplicate |

**Recommendation before next apply:** run `terraform plan` and watch SG changes. Either import console rules into TF or accept TF will reconcile.

---

## Verify SG + peering (copy-paste)

Run from **obs master**:

```bash
# Peering + routes already OK if these pass:
nc -vz 10.110.100.184 6443    # Argo → dev API
nc -vz 10.110.100.184 9100    # Prometheus → node-exporter
nc -vz 10.110.100.184 30301   # Prometheus → KSM
```

Run from **dev master**:

```bash
nc -vz 10.210.100.57 30317    # OTEL
nc -vz 10.210.100.57 30100    # Loki
```

All must succeed. If one fails, check **SG first**, then routes, then peering.

---

## Interview answers (SG-focused)

**Q: Multicluster metrics work in Prometheus but traces/logs don't — where do you look?**

1. Same peering/routes for all ports — SG is per-port
2. node-exporter uses **9100** (not NodePort range) → needed explicit rule on dev
3. OTEL/Loki use NodePort on **obs** → dev must egress (default allow) + obs must ingress from `10.110.0.0/16`
4. `nc -vz` from source cluster master before touching app config

**Q: Pods on different nodes can't reach each other but nodes ping fine?**

- Flannel UDP **8472** — SG must use **full VPC /16**, not subnet /24
- Symptom: CoreDNS ok on one node, app pods fail cross-node

**Q: Why both peering and SG rules?**

- Peering connects VPC routers
- Routes tell routers where to send `10.210.x` traffic
- SGs still drop packets at the ENI even if routing is correct

---

## Codified in Terraform (file paths)

```
kubeadm-on-ec2/dev/networking.tf   → dev CP + worker rules
kubeadm-on-ec2/obs/networking.tf   → obs CP + worker rules
```

Key commits: `9282d3d` (Flannel 8472), `76cf4aa` (9100 in-VPC), cross-VPC rules in `dev/networking.tf` + `obs/networking.tf` (OTEL, Loki, KSM, Argo 6443).

---

## Optional: reconcile TF to match live (before destroy or next apply)

Add to **dev** CP + worker (if you want TF to match console):

```hcl
"prometheus-nodeport-from-obs" = {
  from_port   = 30300
  to_port     = 30400
  ip_protocol = "tcp"
  description = "Prometheus / KSM NodePort scrape from obs"
  cidr_ipv4   = "10.210.0.0/16"
}
```

Add to **obs** CP + worker (alternative to precise ports — matches console):

```hcl
"dev-nodeport-services" = {
  from_port   = 30000
  to_port     = 35000
  ip_protocol = "tcp"
  description = "NodePort services from dev (OTEL, Loki)"
  cidr_ipv4   = "10.110.0.0/16"
}
```

Use **either** precise ports (30100, 30317) **or** the broad range — not both required.

---

*Snapshot reference: `/Users/thawarh/lab-aws-snapshot-20260810.txt`*
