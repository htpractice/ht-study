# Kubernetes Architecture

High-level map of how a cluster works — essential for **CKA/CKAD** troubleshooting and architecture interviews.

## Mental Model

```text
Control Plane (brain)     →  decides what should run, stores state
Worker Nodes (muscle)     →  run pods, report status back
kubectl (you)             →  talks ONLY to API Server
```

**Desired state vs current state:** You declare what you want (YAML/`kubectl`); controllers continuously reconcile until reality matches.

---

## 1. Core Concepts

### Node
A worker or control-plane machine (VM or bare metal) that runs Kubernetes components and/or workloads.

- **Control-plane nodes** run cluster management components.
- **Worker nodes** run application pods.

### Pod
The **smallest deployable unit** in Kubernetes.

- One or more containers sharing network namespace, storage volumes, and IPC.
- Ephemeral — pods are created, replaced, and deleted; don't treat pod IPs as stable.

---

## 2. Control Plane Components

| Component | Role | CKA/CKAD note |
|-----------|------|---------------|
| **kube-apiserver** | Central gateway; all requests (kubectl, controllers, kubelets) pass through it | First place to check auth/API errors |
| **etcd** | Distributed key-value store; cluster state, config, secrets | **Only apiserver** talks to etcd directly |
| **kube-scheduler** | Assigns unscheduled pods to nodes (CPU/memory, taints, affinity) | Pod with no `nodeName` → scheduler's job |
| **kube-controller-manager** | Runs control loops (Deployment, Node, Endpoint, Job controllers, etc.) | Ensures actual state → desired state |

### kube-apiserver — request path
Every `kubectl` command hits the API Server, which performs:

1. **Authentication** — who are you?
2. **Authorization** — RBAC: are you allowed?
3. **Admission** — mutate/validate (optional webhooks)
4. **Persistence** — read/write object in **etcd**

### etcd — why key-value?
- Stores cluster objects as JSON documents under keys — no fixed schema like SQL.
- Flexible for varied resource types (Pods, Services, Secrets, etc.).
- Production: run etcd in **HA** (odd number of members, typically 3).

### Controller Manager — examples
- **Node controller** — node health, evictions when node goes down.
- **Deployment controller** — manages ReplicaSets for rolling updates.
- **Endpoints controller** — populates Endpoints objects (joins Services → Pod IPs).
- **Job controller** — creates pods to run one-off tasks.

---

## 3. Worker Node Components

| Component | Role | CKA/CKAD note |
|-----------|------|---------------|
| **kubelet** | Node agent; creates/destroys pods on this node per API Server instructions | `systemctl status kubelet` on node issues |
| **kube-proxy** | Network proxy; implements **Service** rules on each node | Routes Service IP → backend pod IPs (iptables/IPVS) |
| **Container runtime** | Actually runs containers (containerd, CRI-O) | Kubelet talks to runtime via CRI |

### kubelet
- Receives PodSpecs from API Server.
- Ensures containers in each pod are running and healthy.
- Reports pod/node status back to API Server.
- Does **not** manage containers it didn't get from Kubernetes.

### kube-proxy
- Maintains network rules so **Services** work — stable virtual IP → dynamic pod IPs.
- Enables pod-to-pod and service-to-pod communication within the cluster.
- Does **not** replace CNI for pod networking — works alongside it.

---

## 4. Pod Creation Workflow

What happens when you run `kubectl apply -f pod.yaml`:

```text
1. kubectl  →  API Server     (create Pod object)
2. API Server  →  etcd         (persist desired state)
3. Scheduler watches unscheduled pod  →  picks a node  →  API Server (bind pod to node)
4. API Server  →  kubelet on chosen node  (run the pod)
5. kubelet  →  container runtime  (start containers)
6. kubelet  →  API Server  →  etcd  (update status: Running/Pending/Failed)
7. kubectl get pod  shows current state
```

**Interview one-liner:** "Nothing touches etcd except apiserver; nothing creates pods on nodes except kubelet."

---

## 5. Communication Rules (exam favorites)

| Rule | Detail |
|------|--------|
| kubectl → ? | API Server only |
| API Server → etcd | Only component with direct etcd access |
| Scheduler → ? | Writes binding back via API Server |
| kubelet → ? | Watches API Server for pod assignments on its node |
| Controllers → ? | Watch API Server, reconcile via API Server |

---

## 6. CKA/CKAD Troubleshooting Hooks

| Symptom | Likely component |
|---------|------------------|
| `kubectl` auth/permission denied | API Server (authn/authz) |
| Pod stuck `Pending` | Scheduler (no suitable node, resources, taints) |
| Pod stuck `ContainerCreating` | kubelet, CNI, image pull |
| Pod `Running` but Service unreachable | kube-proxy, Endpoints, selector labels |
| Node `NotReady` | kubelet, container runtime, network |
| Cluster state inconsistent | etcd health, apiserver-etcd connectivity |

**Useful commands:**

```bash
kubectl get componentstatuses          # deprecated but still seen in older material
kubectl get nodes
kubectl describe node <node>
kubectl get pods -n kube-system        # control plane pods (if deployed as pods)
```

---

## 7. Interview Quick Answers

**Q: What is the difference between control plane and worker node?**  
Control plane makes decisions and stores state; worker nodes execute workloads and report back.

**Q: What is the smallest deployable unit?**  
Pod — one or more containers sharing a network namespace.

**Q: Who schedules pods?**  
kube-scheduler assigns pods to nodes; kubelet on that node actually starts them.

**Q: How do Services reach pods with changing IPs?**  
kube-proxy + Endpoints controller maintain rules mapping Service IP → current pod IPs.

**Q: Why is etcd critical?**  
It is the source of truth for all cluster state; losing etcd data means losing the cluster configuration.

---

## Reference

- [Kubernetes Cluster Architecture](https://kubernetes.io/docs/concepts/architecture/)
