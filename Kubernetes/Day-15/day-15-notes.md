# Day 15 — Node Affinity

Advanced pod placement using **node labels** — builds on Day 14 `nodeSelector`, taints, and tolerations. **Pod anti-affinity** covered in a later session.

---

## 1. Evolution: nodeSelector → Node Affinity

| Feature | nodeSelector (Day 14) | nodeAffinity |
|---------|----------------------|--------------|
| Syntax | Simple key=value map | `matchExpressions` with operators |
| Required vs soft | Required only | **Required** or **Preferred** |
| Operators | Equality only | `In`, `NotIn`, `Exists`, `DoesNotExist`, `Gt`, `Lt` |
| Multiple rules | Limited | Multiple terms, weights for preferences |

---

## 2. Two Affinity Types

### requiredDuringSchedulingIgnoredDuringExecution (hard rule)

- Pod **only** schedules on nodes matching the rule
- No match → pod stays **Pending**
- **IgnoredDuringExecution** — if node labels change after pod is running, pod is **not** evicted

```yaml
nodeAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    nodeSelectorTerms:
    - matchExpressions:
      - key: disktype
        operator: In
        values: [ssd]
```

### preferredDuringSchedulingIgnoredDuringExecution (soft rule)

- Scheduler **tries** to match; if no match, still schedules elsewhere
- Use **weight** (1–100) when multiple preferences — higher = more preferred

```yaml
nodeAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
  - weight: 1
    preference:
      matchExpressions:
      - key: nodetype
        operator: In
        values: [db]
```

---

## 3. Operators

| Operator | Meaning |
|----------|---------|
| **In** | Label value is in the list |
| **NotIn** | Label value is not in the list |
| **Exists** | Label key exists (any value) |
| **DoesNotExist** | Label key absent |
| **Gt** / **Lt** | Numeric comparison (version numbers) |

---

## 4. vs Taints/Tolerations (Day 14)

| | Taints/Tolerations | Node Affinity |
|---|-------------------|---------------|
| Direction | Node **repels** pods | Pod **requires/prefers** nodes |
| Guarantees special node? | No | **Required** yes; **Preferred** no |
| Best together | Taint GPU nodes + toleration on GPU pods | **Required** affinity `gpu=true` on same pods |

**Production GPU/dedicated node pattern:**

```text
Node: taint gpu=true:NoSchedule  +  label nodetype=gpu
Pod:  toleration gpu=true        +  required affinity nodetype In [gpu]
```

---

## 5. Hands-on Lab

| File | Affinity type | Rule | Expected behavior |
|------|---------------|------|-------------------|
| `affinity-ns.yaml` | — | namespace `affinity` | Apply first |
| `affinity-deploy.yaml` | **Required** | `disktype In [ssd]` | All pods **only** on SSD-labeled node |
| `affinity-db-deploy.yaml` | **Preferred** | `nodetype In [db]` | Prefer DB nodes; schedule elsewhere if needed |
| `affinity-no-pref-deploy.yaml` | **Preferred** | `disktype In [hdd]` | No HDD nodes → schedules anywhere |
| `practice-output.md` | — | `kc get pods -o wide` | Captured results proving each case |

### Setup labels (before deploys)

```bash
kc apply -f affinity-ns.yaml
kc label node cka-cluster01-worker  disktype=ssd
kc label node cka-cluster01-worker2 disktype=ssd-nvme
kc label node cka-cluster01-worker2 nodetype=db
kc get nodes --show-labels
```

### Apply and verify

```bash
kc apply -f affinity-deploy.yaml
kc apply -f affinity-db-deploy.yaml
kc apply -f affinity-no-pref-deploy.yaml
kc get pods -n affinity -o wide
```

---

## 6. Practice Output — What We Proved

From `practice-output.md`:

### affinity-pod (required `disktype=ssd`)

```text
All 3 pods → cka-cluster01-worker only
```

Only `worker` had `disktype=ssd`. **Required** affinity blocked scheduling on `worker2` (`ssd-nvme` ≠ `ssd`). Hard rule works.

### affinity-db-pod (preferred `nodetype=db`)

```text
2 pods → worker2 (has nodetype=db)
1 pod  → worker
```

**Preferred** — scheduler favored DB-labeled node but didn't require it. Pods still land elsewhere.

### affinity-no-pref-pod (preferred `disktype=hdd`)

```text
1 pod → worker, 2 pods → worker2
```

No node has `disktype=hdd`. **Preferred** rule unmatched → scheduler placed pods on any available node. Soft rule does not block scheduling.

---

## 7. CKA Exam Tips

- **Required** → Pending if no match; **Preferred** → always schedules if resources exist
- `IgnoredDuringExecution` = label changes after scheduling don't evict the pod
- Generate base: `kc create deployment ... --dry-run=client -o yaml`, vim-edit `affinity` block
- `nodeSelectorTerms` is a list — OR between terms, AND within matchExpressions
- **Anti-affinity** (pod spread / avoid same node) — separate topic, coming in later video

### Dry-run template

```bash
kc create deployment affinity-pod --image=nginx -n affinity \
  --dry-run=client -o yaml > affinity-deploy.yaml
# vim: add spec.template.spec.affinity.nodeAffinity section
```

---

## 8. Coming Next — Pod Anti-Affinity

Not covered today. Will address spreading pods across nodes (e.g. don't run two replicas on same node) using `podAntiAffinity` — different from **node** affinity.

---

## Reference

- [Assign Pods to Nodes — Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity)
- [Node Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity)
