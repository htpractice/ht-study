# Day 13 — Static Pods, Manual Scheduling, Labels/Selectors, and Annotations

Essential **CKA** topics: how control plane components bootstrap, how to pin pods to nodes, and how Kubernetes groups resources.

---

## 1. Static Pods

Static pods are managed directly by the **kubelet** on a specific node — **not** by the API server scheduler or controllers.

### Why they matter
Control plane components (kube-apiserver, kube-scheduler, kube-controller-manager, etcd) must run **before** the cluster is fully operational. On kubeadm clusters, these are often static pods on the control-plane node.

### How they work
- Kubelet watches a manifest directory (default on kubeadm: **`/etc/kubernetes/manifests`**)
- YAML file appears → kubelet creates the pod
- YAML file removed → kubelet terminates the pod
- YAML restored → kubelet recreates the pod

### Mirror pods
Static pods also appear in `kubectl get pods -n kube-system` as **mirror pods** — read-only copies the API server uses for visibility. You manage them via the **manifest file on the node**, not `kubectl delete pod`.

### CKA troubleshooting

```bash
# On control-plane node
ls /etc/kubernetes/manifests
cat /etc/kubernetes/manifests/kube-scheduler.yaml

# Check kubelet static pod path (if not default)
ps aux | grep kubelet | grep config
grep -i staticPodPath /var/lib/kubelet/config.yaml

# Container-level debug on node
crictl pods
crictl ps
```

**Exam scenario:** kube-scheduler down → check static pod manifest in `/etc/kubernetes/manifests` → fix YAML → kubelet restarts it automatically.

### If you remove kube-scheduler manifest

| Effect | Detail |
|--------|--------|
| Scheduler pod | Terminated by kubelet |
| Existing pods | Keep running — cluster doesn't crash |
| New pods | Stuck **Pending** — nothing assigns them to nodes |
| Recovery | Restore manifest file → kubelet recreates scheduler pod |

**Workaround while scheduler is down:** set `nodeName` on a pod to bypass scheduling (see below).

---

## 2. Manual Scheduling

Normally the **kube-scheduler** watches unscheduled pods (no `nodeName`) and picks a node.

### nodeName — hard pin (bypass scheduler)

```yaml
spec:
  nodeName: worker-node-1
```

- Scheduler **ignores** the pod
- Target node's kubelet runs it directly
- Use for troubleshooting or CKA exam tasks — **not** recommended for production

### Preferred alternatives (production)

| Method | Behavior |
|--------|----------|
| **nodeSelector** | Simple label match — pod only runs on nodes with matching labels |
| **nodeAffinity** | Flexible rules (required/preferred, operators like `In`, `NotIn`) |
| **taints + tolerations** | Restrict which pods can run on which nodes |

### CKA dry-run pattern

```bash
kc run nginx --image=nginx --dry-run=client -o yaml > pod.yaml
# vim: add spec.nodeName: <node-from-kc-get-nodes>
kc apply -f pod.yaml
```

---

## 3. Labels and Selectors

Primary mechanism for grouping and filtering resources across the cluster.

### Labels
Key-value pairs in `metadata.labels` — no built-in meaning; you define them.

```yaml
metadata:
  labels:
    app: nginx
    env: prod
    tier: frontend
```

### Selectors
Controllers and CLI use selectors to find matching objects.

**Equality-based (`matchLabels`):**

```yaml
selector:
  matchLabels:
    app: nginx
```

**Set-based (`matchExpressions`):**

```yaml
selector:
  matchExpressions:
  - key: env
    operator: In
    values: [prod, staging]
  - key: tier
    operator: NotIn
    values: [batch]
```

### CLI filtering

```bash
kc get pods -l app=nginx
kc get pods -l 'env in (prod,staging)'
kc get pods --selector tier=frontend
```

### Where you've already used this

| Resource | Selector purpose |
|----------|------------------|
| **Deployment** `matchLabels` | Which pods this ReplicaSet owns |
| **Service** `selector` | Which pods receive traffic (endpoints) |
| **DaemonSet** `matchLabels` | Pod template labels on every node |

---

## 4. Annotations vs Labels

| | Labels | Annotations |
|---|--------|-------------|
| **Purpose** | Identify, select, group resources | Store non-identifying metadata |
| **Used in selectors** | Yes | No |
| **Examples** | `app: nginx`, `env: prod` | build version, git SHA, owner email, tool config |

```yaml
metadata:
  labels:
    app: nginx
  annotations:
    prometheus.io/scrape: "true"
    contact: "platform-team@example.com"
```

External tools (Prometheus, ingress controllers, cert-manager) often read **annotations**, not labels.

---

## 5. Labels vs Namespaces

| | Namespaces | Labels/Selectors |
|---|------------|------------------|
| **Purpose** | Administrative isolation boundary | Logical grouping/filtering |
| **Scope** | Hard boundary for names (Service DNS, RBAC, quotas) | Cross-namespace or within namespace |
| **Example** | `prod` vs `staging` namespace | `env: prod` label on pods in any namespace |

Namespaces isolate; labels organize. Use both together.

---

## 6. CKA Exam Tips

- Static pod issues → SSH to control-plane node → check `/etc/kubernetes/manifests`
- Pod stuck Pending → scheduler health, resources, taints, or use `nodeName` if exam requires it
- Never `kubectl delete` a static pod to fix it — edit/remove the **manifest file** on the node
- Generate pod YAML: `--dry-run=client -o yaml`, then vim-edit `nodeName` or labels
- `kubectl get pods -n kube-system` shows control plane components (often mirror pods)

---

## Reference

- [Static Pods](https://kubernetes.io/docs/concepts/workloads/pods/#static-pods)
- [Assign Pods to Nodes](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
- [Labels and Selectors](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)
