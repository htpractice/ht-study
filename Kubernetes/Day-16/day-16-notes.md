# Day 16 — Resource Requests, Limits, QoS, and Metrics Server

How Kubernetes **schedules**, **governs**, and **monitors** CPU and memory — core **CKA/CKAD** material.

---

## 1. Requests vs Limits

| | Requests | Limits |
|---|----------|--------|
| **Purpose** | Minimum guaranteed for **scheduling** | Maximum allowed at **runtime** |
| **Used by** | Scheduler (can this node fit the pod?) | kubelet/cgroups (enforce cap) |
| **If exceeded** | N/A — reservation only | Memory: **OOM kill**; CPU: **throttled** |
| **Interview line** | "Where can this pod live?" | "How much can it consume?" |

```yaml
resources:
  requests:
    cpu: 250m
    memory: 50Mi
  limits:
    cpu: 500m
    memory: 150Mi
```

---

## 2. Resource Units — Ki, Mi, Gi (Memory) and CPU

### Memory — binary (IEC) suffixes — use in exams

| Suffix | Name | Math | Example |
|--------|------|------|---------|
| **Ki** | Kibibyte | × 1024 | `128Ki` |
| **Mi** | Mebibyte | × 1024² | `50Mi`, `150Mi`, `256Mi` |
| **Gi** | Gibibyte | × 1024³ | `1Gi` |

Decimal (less common): `K`, `M`, `G` (powers of 1000).

### CPU

| Unit | Meaning |
|------|---------|
| `1` | 1 full core |
| `500m` | 500 millicores (0.5 core) |
| `0.5` | same as `500m` |

### Exam traps

```yaml
memory: 150m     # WRONG — 'm' = millibytes (negligible!)
memory: 150Mi    # correct
cpu: 500m        # correct — millicores
```

---

## 3. What Happens When Limits Are Exceeded

| Resource | Over limit behavior |
|----------|---------------------|
| **Memory** | Container **OOMKilled** → restart → CrashLoopBackOff if repeated |
| **CPU** | **Throttled** (slowed down) — not killed |

**Day 16 lab:** `limit-pod.yaml` uses `polinux/stress` to **intentionally exceed** memory limit:

| Setting | Value | Stress tries | Result |
|---------|-------|--------------|--------|
| memory limit | `150Mi` | `--vm 1 --vm-bytes 200Mi` | Exceeds limit → **OOMKilled** (exit 137) |

**Common mistake:** `--vm-bytes` without `--vm 1` does **not** start memory workers — only CPU/other flags run. You get `Exit Code 1` / `Reason: Error`, not `OOMKilled`. Always pair `--vm N` with `--vm-bytes`.

```yaml
args:
- --vm
- "1"
- --vm-bytes
- "200Mi"
- --vm-hang
- "1"
```

**What to expect in `describe pod` when OOM works:**

```text
Last State:  Terminated
Reason:      OOMKilled
Exit Code:   137
```

**Pending** is unrelated — that means scheduling failed, not memory enforcement.

See `practice-output.md` — original run showed Error/1 (missing `--vm`); fixed manifest should show OOMKilled.

---

## 4. Quality of Service (QoS) Classes

Kubernetes assigns every pod a QoS class — affects **eviction order** under node pressure.

| QoS Class | Condition | Eviction priority |
|-----------|-----------|-------------------|
| **Guaranteed** | Every container: limits = requests (for cpu and memory) | Last evicted |
| **Burstable** | At least one request or limit set; not Guaranteed | Middle |
| **BestEffort** | No requests/limits at all | **First evicted** |

Our lab pod: requests `50Mi`/`250m`, limits `150Mi`/`500m` → **Burstable**.

---

## 5. Metrics Server

Cluster add-on that powers **`kubectl top`**.

```bash
# Install (Kind/local — see metric-server.yaml)
kc apply -f metric-server.yaml

# Verify
kc get deployment metrics-server -n kube-system
kc top nodes
kc top pods -n resourcelimits
```

| Command | Shows |
|---------|--------|
| `kubectl top node` | CPU/memory usage per node |
| `kubectl top pod` | CPU/memory usage per pod |

**Requires Metrics Server** — not built into core Kubernetes. Also used by **HPA** (Horizontal Pod Autoscaler) for scaling decisions.

**Kind note:** `metric-server.yaml` includes `--kubelet-insecure-tls` for local clusters with self-signed certs.

---

## 6. Hands-on Lab

| File | Purpose |
|------|---------|
| `resourcelimits.yaml` | Namespace |
| `metric-server.yaml` | Metrics Server install (kube-system) |
| `limit-pod.yaml` | Stress pod that exceeds memory limit |
| `practice-output.md` | `kubectl describe pod` showing CrashLoopBackOff |

### Lab flow

```bash
kc apply -f resourcelimits.yaml
kc apply -f metric-server.yaml
# wait for metrics-server ready
kc top nodes

kc apply -f limit-pod.yaml
kc get pod limit-pod -n resourcelimits -w
kc describe pod limit-pod -n resourcelimits    # OOM / CrashLoopBackOff
kc top pod limit-pod -n resourcelimits
```

### Interpreting the stress failure

```text
Limits:     memory 150Mi
Stress:     --vm-bytes 250Mi   ← asks for MORE than limit
→ kubelet kills container when memory exceeds cgroup limit
→ Restart Count increases, CrashLoopBackOff
```

To fix: raise `limits.memory` above `250Mi` OR lower `--vm-bytes` below `150Mi`.

---

## 7. CKA/CKAD Exam Tips

- **Requests** affect scheduling; **limits** affect runtime enforcement
- Memory over limit = **OOMKilled** (check `describe pod` → Last State, exit code 137)
- CPU over limit = throttled, pod keeps running
- `kubectl top` needs Metrics Server running
- Set resources on **every container** in multi-container pods
- Generate pod with resources: dry-run → vim-edit `resources` block

```bash
kc run limit-pod --image=polinux/stress -n resourcelimits \
  --dry-run=client -o yaml > limit-pod.yaml
```

---

## Reference

- [Manage Resources for Containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Resource QoS](https://kubernetes.io/docs/concepts/workloads/pods/pod-qos/)
- [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
