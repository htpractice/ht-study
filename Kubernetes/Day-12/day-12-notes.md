# Day 12 — DaemonSets, Jobs, and CronJobs

Workload controllers beyond Deployments — **DaemonSets** are high-yield for **CKA**; **Jobs** and **CronJobs** for **CKAD**.

---

## 1. Workload Controller Comparison

| Controller | Runs | Replicas | Typical use |
|------------|------|----------|-------------|
| **Deployment** | N pods anywhere in cluster | `replicas: N` | Stateless apps (nginx, API) |
| **DaemonSet** | **1 pod per node** (or subset) | No `replicas` — one per matching node | Monitoring, logging, CNI agents |
| **Job** | Pods until task **completes once** | `completions`, `parallelism` | Migrations, batch, one-off scripts |
| **CronJob** | Job on a **schedule** | Cron syntax | Backups, reports, cleanup |

**Interview one-liner:** Deployment scales horizontally by count; DaemonSet scales **with nodes** — add a node, get a pod automatically.

---

## 2. DaemonSet

### Concept
Ensures **exactly one copy** of a pod runs on every eligible node (or nodes matching `nodeSelector` / affinity).

- New node joins → DaemonSet schedules a pod on it automatically.
- Node removed → pod on that node goes away.
- **Ignores `replicas`** — count is driven by node count.

### Typical use cases
- **Monitoring agents** — Prometheus node-exporter (this lab)
- **Logging agents** — Fluentd, Filebeat
- **Networking/CNI** — Calico, Flannel, Weave (often deployed as DaemonSet)
- **kube-proxy** — runs on every node (usually managed by cluster)

### CKA gotcha — control-plane nodes
DaemonSets may **not** appear on control-plane/master nodes by default due to **taints** (`node-role.kubernetes.io/control-plane:NoSchedule`). Fix with **tolerations** on the DaemonSet pod spec if the agent must run everywhere.

```bash
kc get daemonset -n daemon-monitoring
kc get pods -n daemon-monitoring -o wide    # compare pod count vs node count
kc describe daemonset daemon-set-node-exporter -n daemon-monitoring
```

### Hands-on lab (this folder)

```text
daemon-ns.yaml  →  daemonset.yaml
  (namespace)       (node-exporter DaemonSet on every worker node)
```

```bash
kc apply -f daemon-ns.yaml
kc apply -f daemonset.yaml
kc get ds,pods -n daemon-monitoring -o wide
```

---

## 3. Job

### Concept
Creates one or more pods that run until the task **finishes successfully**.

- Pod transitions to **Completed** when the command exits 0.
- Used for finite work: DB migration, data processing, cluster bootstrap tasks.

### Key fields
- `completions` — how many successful pod runs needed
- `parallelism` — how many pods run at once
- `backoffLimit` — retries before marking Job failed

### Imperative / dry-run (CKAD)

```bash
kc create job migrate --image=busybox --dry-run=client -o yaml -- sh -c "echo done"
```

---

## 4. CronJob

### Concept
Creates a **Job** on a schedule using cron syntax (5 fields):

```text
┌──────────── minute (0-59)
│ ┌────────── hour (0-23)
│ │ ┌──────── day of month (1-31)
│ │ │ ┌────── month (1-12)
│ │ │ │ ┌──── day of week (0-6)
│ │ │ │ │
* * * * *
```

Example: `0 2 * * *` — every day at 02:00.

### CKAD notes
- `schedule` field is required
- `startingDeadlineSeconds` — skip if too late
- `concurrencyPolicy`: `Allow`, `Forbid`, `Replace`

```bash
kc create cronjob backup --image=busybox --schedule="0 1 * * *" --dry-run=client -o yaml -- sh -c "echo backup"
```

---

## 5. Deployment vs DaemonSet — interview answer

**Q: When would you use DaemonSet instead of Deployment?**  
When every node needs its own copy of an agent (monitoring, logging, networking) — not when you want N replicas spread arbitrarily.

**Q: What happens when you add a node?**  
DaemonSet controller schedules a new pod on that node. Deployment does nothing unless you scale replicas.

---

## 6. CKA/CKAD Exam Tips

- Generate YAML: `--dry-run=client -o yaml` then vim-edit
- DaemonSet kind: `DaemonSet` (case-sensitive), apiVersion: `apps/v1`
- Selector must match template labels (same rule as Deployment)
- Check Job status: `kc get jobs`, `kc logs job/<name>`
- Check CronJob: `kc get cronjobs`, `kc get jobs` (CronJob spawns Jobs)

---

## Reference

- [DaemonSet](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)
- [Job](https://kubernetes.io/docs/concepts/workloads/controllers/job/)
- [CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)
