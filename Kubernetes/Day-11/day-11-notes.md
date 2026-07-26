This video from the *CKA 2024* series covers the implementation and management of **multi-container pods** in Kubernetes, specifically focusing on **Init Containers**.

### **1. Key Concepts**

- **Multi-Container Pods:** Pods can run multiple containers that share the same network and storage resources.
- **Init Containers:** Specialized containers that run **before** the main application container.
  - Main container starts only after all init containers complete successfully.
  - If an init container fails, Kubernetes restarts it until it succeeds.
  - Init containers cannot be added/removed on a running pod — delete and recreate the pod to change them.
- **Environment Variables:** Pass configuration into containers via `env` in the pod spec.
- **Commands and Arguments:** Override container entrypoints with `command` and `args` — commonly used in init containers for `nslookup` dependency checks.

### **2. Init Container Sequencing**

- **Sequential execution:** Multiple init containers run in manifest order; each must complete before the next starts.
- **Blocking:** Pod stays in `Init:N/M` until all init containers finish; main app does not start until then.
- **Completed state:** Init containers terminate with reason `Completed` once done — this is expected, not an error.

### **3. Init vs Sidecar**

| | Init Container | Sidecar Container |
|---|----------------|-------------------|
| **When it runs** | Before app starts | Alongside app for full pod lifecycle |
| **Purpose** | Setup, wait for deps | Logging, proxy, config sync |
| **Example** | `until nslookup svc...` | Envoy, log forwarder |

**Sidecar common uses:** log forwarding, service mesh proxy, config syncing, data sync. Sidecars share `localhost` and volumes with the main container.

### **4. Hands-on Lab — Two Init Containers (SVC + DB)**

This folder demonstrates a dependency chain across four manifests:

```text
multicon-ns.yaml  →  multicon-deploy.yaml  →  multi-con-svc.yaml  →  muti-conatiner-pod.yaml
   (namespace)      (nginx + redis pods)      (web + db Services)     (2 inits → app)
```

**Apply order:**

```bash
kc delete namespace multicon --ignore-not-found   # clean reset
kc apply -f multicon-ns.yaml
kc apply -f multicon-deploy.yaml
kc apply -f multi-con-svc.yaml
kc get endpoints -n multicon                      # confirm both services have backends
kc apply -f muti-conatiner-pod.yaml
kc get pod multi-con-pod -n multicon -w           # Init:0/2 → Init:2/2 → Running
```

**Label separation (important):**

| Resource | Labels | Role |
|----------|--------|------|
| Deployment pods | `app: multi-con-demo-nginx` | Backend — selected by both Services |
| Init pod | `env: multi-con-demo` | Consumer — waits on Service DNS, not an endpoint |

**DNS the init containers wait for (in order):**

```text
multi-cont-svc.multicon.svc.cluster.local      # init 1
multi-cont-dbsvc.multicon.svc.cluster.local    # init 2
```

### **5. Troubleshooting — CrashLoopBackOff (build, break, fix)**

When a multi-container Deployment pod fails, events often only say which container failed — not why.

**Always target the failing container:**

```bash
kc describe pod <pod-name> -n multicon          # Last State, Exit Code (1=error, 137=OOM)
kc logs <pod-name> -n multicon -c db-container --previous
kc logs <pod-name> -n multicon -c nginx-container
```

**What broke in practice:** `mysql:latest` without required env vars (`MYSQL_ROOT_PASSWORD`) and tight memory limits → `db-container` CrashLoopBackOff. Fixed by switching to `redis:latest` and aligning Service port `6379` with `containerPort`.

**Key lesson:** `nslookup` in init containers proves DNS exists — not that the DB process is healthy.

### **6. Debugging Commands**

```bash
kc logs multi-con-pod -n multicon -c init-svc-check-container
kc logs multi-con-pod -n multicon -c init-dbsvc-check-container
kc logs multi-con-pod -n multicon -c app-container
kc describe pod multi-con-pod -n multicon
```

### **7. CKA Exam Tips**

- Generate YAML with dry-run: `kc run ... --dry-run=client -o yaml` or `kc create deployment ... --dry-run=client -o yaml`
- Export existing resources: `kc get <resource> <name> -o yaml` (not `kubectl edit`)
- Use `-c <container-name>` and `--previous` with `kubectl logs` in multi-container pods
