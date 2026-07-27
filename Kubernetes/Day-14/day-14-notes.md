# Day 14 — Taints, Tolerations, and Node Selectors

How Kubernetes **restricts** and **directs** pod placement — high-yield for **CKA** scheduling questions.

---

## 1. Mental Model

| Mechanism | Applied to | Behavior |
|-----------|------------|----------|
| **Taints** | Node | "Repel pods unless they tolerate me" |
| **Tolerations** | Pod | "I can run on tainted nodes" |
| **nodeSelector** | Pod | "Schedule me only on nodes with this label" |

**Key difference:**
- Taints/tolerations = **restriction** (block unwanted pods) — does **not** guarantee pod lands on tainted node
- nodeSelector = **directive** (pod chooses node type) — pod **only** runs on matching nodes

For AND/OR and soft preferences → **nodeAffinity** (next level up).

---

## 2. Taints and Tolerations

### Taint effects

| Effect | Behavior |
|--------|----------|
| **NoSchedule** | New pods without toleration won't be scheduled |
| **PreferNoSchedule** | Scheduler tries to avoid, not strict |
| **NoExecute** | Existing pods without toleration are **evicted** |

### Imperative commands

```bash
# Add taint
kc taint nodes <node-name> key=value:NoSchedule

# Remove taint (note trailing dash)
kc taint nodes <node-name> key=value:NoSchedule-

# Example from lab
kc taint node cka-cluster01-worker2 gpu=true:NoSchedule
```

### Pod toleration (see `tolleration-pod.yaml`)

```yaml
tolerations:
- key: "gpu"
  operator: "Equal"
  value: "true"
  effect: "NoSchedule"
```

Must match taint **key**, **value**, and **effect**.

### Built-in node taints (automatic)

| Taint | When |
|-------|------|
| `node.kubernetes.io/not-ready` | Node not ready |
| `node.kubernetes.io/unreachable` | Node unreachable |
| `node.kubernetes.io/memory-pressure` | Low memory |
| `node.kubernetes.io/disk-pressure` | Low disk |
| `node.kubernetes.io/pid-pressure` | PID pressure |
| `node.kubernetes.io/unschedulable` | Node cordoned |
| `node.cloudprovider.kubernetes.io/uninitialized` | External cloud provider init |

Control-plane nodes also have `node-role.kubernetes.io/control-plane:NoSchedule` by default — why DaemonSets skip masters unless tolerations are added (Day 12).

---

## 3. Node Selectors

Simple label match — pod runs **only** on nodes with matching labels.

```bash
# Label a node first
kc label node cka-cluster01-worker2 gpu=true

# Verify
kc get nodes --show-labels
```

Pod spec (see `nodeselector-pod.yaml`):

```yaml
nodeSelector:
  gpu: "true"
```

Pod stays **Pending** until a matching node exists.

---

## 4. Resource Units — Ki, Mi, Gi (and CPU)

When setting `resources` on pods (often combined with scheduling labs):

### Memory — use binary (IEC) suffixes

| Suffix | Name | Calculation | Example |
|--------|------|-------------|---------|
| **Ki** | Kibibyte | × 1024 | `128Ki` |
| **Mi** | Mebibyte | × 1024² | `64Mi`, `128Mi` |
| **Gi** | Gibibyte | × 1024³ | `1Gi` |

Decimal alternatives (less common in K8s): `K`, `M`, `G` (powers of 1000).

```yaml
resources:
  requests:
    memory: 64Mi
    cpu: 100m
  limits:
    memory: 128Mi
    cpu: 500m
```

### CPU units

| Unit | Meaning |
|------|---------|
| `1` | 1 full core |
| `500m` | 500 millicores (0.5 core) |
| `0.5` | same as 500m |

### Exam traps

```yaml
memory: 128m    # WRONG — 'm' = millibytes (tiny!)
memory: 128Mi   # correct — mebibytes
cpu: 100m       # correct — millicores
```

---

## 5. Hands-on Lab

| File | Purpose |
|------|---------|
| `tolleration-pod.yaml` | Pod with GPU taint toleration |
| `nodeselector-pod.yaml` | Pod pinned via `nodeSelector: gpu: "true"` |
| `day-14-commands.md` | Command sequence used in practice |

**Lab flow:**

```bash
# 1. Taint a worker node
kc taint node <worker> gpu=true:NoSchedule

# 2. Apply toleration pod — can schedule on tainted node
kc apply -f tolleration-pod.yaml

# 3. Label another node, apply nodeSelector pod
kc label node <worker2> gpu=true
kc apply -f nodeselector-pod.yaml

# 4. Verify placement
kc get pods -o wide
kc describe pod tolleration-pod
kc describe pod nodeselector-pod
```

---

## 6. Comparison Summary

| | Taints/Tolerations | nodeSelector |
|---|-------------------|--------------|
| **Control** | Node repels pods | Pod chooses nodes |
| **Guarantees landing on special node?** | No — other untainted nodes still work | Yes — only matching nodes |
| **Use case** | Dedicated GPU/memory nodes, control-plane isolation | Simple workload pinning |

---

## 7. CKA Exam Tips

- Remove taint: append `-` → `key=value:NoSchedule-`
- Toleration must match key, value, **and** effect exactly
- `nodeSelector` requires node labels to exist first — pod Pending if no match
- Generate pod YAML: `--dry-run=client -o yaml`, vim-edit tolerations/nodeSelector
- Memory: always **Mi/Gi**, never lowercase **m** for memory

---

## Reference

- [Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
- [Assign Pods to Nodes](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
- [Resource units](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
