# kubeadm & cluster operations — interview notes

Quick reference for CrowdStrike **Cloud & Kubernetes at Scale** topics.

---

## kubeadm vs kind vs managed (EKS)

| | kubeadm | kind | EKS/GKE |
|--|---------|------|---------|
| Use | Bare metal, on-prem, learning | Local dev, CKA | Production default |
| Upgrade | `kubeadm upgrade` | `kind upgrade node-image` | Managed control plane + node groups |
| Static pods | On real CP node | Inside container | AWS/GCP manages CP |

**Line:** "I use kind for fast CKA practice; kubeadm for understanding prod install/upgrade semantics; EKS for what we run at Autodesk."

---

## Control plane bootstrap

```
kubeadm init
  → static pods in /etc/kubernetes/manifests (apiserver, scheduler, controller-manager, etcd)
  → kubelet runs them
  → API server comes up
  → join workers with kubeadm join
  → CNI required before nodes Ready
```

---

## Upgrade order (must know)

1. **Control plane** first (`kubeadm upgrade apply`)
2. **kubelet/kubectl** on CP node
3. **Workers** one at a time: **drain → upgrade → uncordon**

**Never skip minor versions** with kubeadm.

---

## drain / cordon

```bash
kubectl cordon node1          # no new pods scheduled
kubectl drain node1 \         # evict existing pods
  --ignore-daemonsets \
  --delete-emptydir-data
kubectl uncordon node1
```

| Flag | Why |
|------|-----|
| `--ignore-daemonsets` | DaemonSets stay (node exporter, CNI) |
| `--delete-emptydir-data` | Allow evicting pods using emptyDir |
| `--force` | Single-replica pods without PDB (use carefully) |

**Interview:** "Drain respects PDB — if minAvailable blocks eviction, drain waits or fails until you scale up or adjust PDB."

---

## PodDisruptionBudget (PDB)

```yaml
minAvailable: 2        # or maxUnavailable: 1
selector:
  matchLabels:
    app: order-api
```

- Protects during **voluntary** disruptions (drain, deployment rollout)
- Does **not** stop involuntary failures (node crash)
- Pair with **replicas ≥ minAvailable + headroom**

---

## Version skew policy (simplified)

| Component | Skew |
|-----------|------|
| kube-apiserver | Reference version |
| kubelet | Up to **2 minors** older than apiserver |
| kubectl | Within **1 minor** of apiserver |
| kubeadm | Matches target cluster version during upgrade |

---

## Autoscaling (connect to Day 16–17)

| Layer | What scales |
|-------|-------------|
| **HPA** | Pod replicas (CPU, memory, custom metrics) |
| **VPA** | Pod resource requests (less common in prod) |
| **Cluster Autoscaler** | Node count in node group |

**Line:** "HPA needs metrics-server or Prometheus adapter; CA needs cloud ASG / node pool headroom."

---

## Multi-cluster (talk track)

- One cluster per env/region or fleet per business unit
- **GitOps** (Argo app-of-apps) for consistent deploys
- Central observability (Mimir/Dynatrace) with cluster label
- **Upgrade:** staging cluster first, then prod fleet wave

---

## Cost optimization (your Oracle story fits)

- Right-size requests/limits (avoid 2 CPU request / 10m usage)
- Spot/preemptible for fault-tolerant workloads
- Orphaned volume cleanup (~20% storage — your Oracle win)
- Namespace quotas, idle workload reviews

---

## Security tie-in

- **NP default-deny** + explicit allow (Calico generator — Oracle)
- **CVE:** golden base image → rebuild → pipeline → rolling deploy
- **Secrets:** not in Git; rotation via Vault/ESO
- **Upgrade window:** patch kubelet for CVE with tested drain/PDB plan

---

## CKA commands to keep warm

```bash
kubeadm token create --print-join-command
kubectl get pods -n kube-system -o wide
kubectl describe node | grep -i taint
export KUBECONFIG=...   # switch contexts
crictl ps               # on node
```
