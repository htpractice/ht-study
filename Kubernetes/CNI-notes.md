# Kubernetes Networking Deep Dive — CNI, Pause Container & Runtime Lifecycle

Guest session (Saiyam Pathak) — goes **below** CKA exam surface but essential for troubleshooting. Connects [Day 26 NetworkPolicy](./Day-26/day-26-notes.md) (policy needs a CNI that enforces) and [Day 28 DNS](./Day-28/day-28-notes.md) (names resolve only after packets can flow).

**Quick read:** [cni-quick-read.md](./cni-quick-read.md) · **Lab output:** [cni-practice-output.md](./cni-practice-output.md)

**CKA truth:** you won't be asked to configure CNI plugins on the exam — but `ContainerCreating` stuck, netpol not working, and multi-container pods make sense only with this mental model.

---

## 1. Big picture — two separate jobs

```text
JOB 1 — Run containers     CRI → containerd → runc  (OCI)
JOB 2 — Wire the network   CNI plugin (Calico, Flannel, Cilium…)
```

Kubernetes **does not** ship pod networking. It ships the **hook** (CNI) and expects a plugin to assign IPs, routes, and (optionally) enforce NetworkPolicy.

---

## 2. Manifest → running pod (full lifecycle)

```text
You: kubectl apply -f pod.yaml
        │
        ▼
API Server  →  validate  →  etcd (desired state)
        │
        ▼
Scheduler  →  pick node
        │
        ▼
Kubelet (on that node)  →  sees Pod bound to me
        │
        ├── 1. Pull images (via CRI → containerd)
        │
        ├── 2. Create POD SANDBOX (pause container)  ← network namespace born here
        │       containerd → runc → pause process sleeping
        │
        ├── 3. CNI ADD  →  plugin assigns IP, creates veth, routes
        │
        └── 4. Create app container(s)  →  join sandbox netns
                containerd → runc → nginx/redis/… actually runs
```

**Interview one-liner:** Kubelet doesn't run Docker directly — it speaks **CRI** to **containerd**, which invokes **runc** to create Linux namespaces and cgroups per OCI spec.

---

## 3. Runtime stack (Docker → CRI → OCI → runc)

| Era / layer | What it is |
|-------------|------------|
| **Docker** (legacy) | Was bundled early; kubelet used Docker shim — **removed** (dockershim gone) |
| **CRI** | Kubelet ↔ runtime API (containerd, CRI-O) |
| **containerd** | High-level runtime — images, containers, namespaces |
| **runc** | Low-level OCI runtime — actually creates container (fork, namespaces, cgroups) then **exits** |
| **OCI** | Open standard — image format + runtime spec (same idea as portable container images everywhere) |

```text
kubelet  --CRI gRPC-->  containerd  --calls-->  runc  --creates-->  container process
                                              runc exits; container keeps running
```

**Why runc "exits":** runc is a **launcher**, not a supervisor. containerd/shim keeps the container alive after runc finishes setup.

---

## 4. Pause container — the "crazy" part

Every pod gets an invisible **infrastructure container** first:

| | |
|---|---|
| **Image** | `registry.k8s.io/pause:3.x` (tiny ~700KB) |
| **Job** | Hold the pod's **network namespace** (and IPC; optionally PID) open |
| **Process** | Literally sleeps — does almost nothing |
| **Why** | Linux netns dies when the last process inside exits |

### Without pause

```text
Container A starts  →  creates netns  →  A exits  →  netns destroyed  →  IP gone
Container B starts  →  new netns  →  different IP  →  NOT one pod
```

### With pause

```text
pause starts     →  netns created, IP assigned (CNI)
app containers   →  join SAME netns  →  same Pod IP, localhost works
pause keeps running  →  netns stays alive even if app container restarts
```

**Multi-container pod:** sidecar + app share IP because they share **pause's network namespace** — not because Kubernetes magic, because of Linux namespaces.

```bash
# On a node — see sandbox + app containers
crictl pods
crictl ps
# pause often shows as POD / sandbox container
```

---

## 5. CNI (Container Network Interface)

When the pod sandbox is created, kubelet invokes the CNI plugin:

```text
CNI ADD  pod=<id>  netns=/var/run/netns/...
    │
    ▼
Plugin (Calico / Flannel / Cilium / kind-net)
    ├── create veth pair
    ├── move one end into pod netns (eth0)
    ├── assign IP from pod CIDR
    ├── set routes / bridge / overlay / BGP
    └── (Calico/Cilium) install policy dataplane
```

| Plugin | Style | NetworkPolicy enforcement |
|--------|-------|---------------------------|
| **Flannel** | Simple overlay | No (basic connectivity) |
| **kind-net** | Kind default | No |
| **Calico** | BGP / overlay / eBPF | **Yes** (standard NP) |
| **Cilium** | eBPF | **Yes** |

**Day 26 lab:** `disableDefaultCNI: true` + Calico — nodes NotReady until CNI runs because **no plugin = no pod IPs**.

---

## 6. veth pairs — pod ↔ host ↔ cluster

```text
┌──────────────── Pod netns ────────────────┐
│  pause + app containers                   │
│  eth0  ←── veth peer ──→  host side       │
└───────────────────────────────────────────┘
                              │
                    bridge / routing / overlay
                              │
                    other pods on this or other nodes
```

- **veth** = virtual ethernet cable — always in pairs (one end in pod, one on host)
- Host side connects to **linux bridge**, **route table**, or **tunnel** (VXLAN, IPIP) depending on CNI
- Outbound pod traffic: eth0 → veth → host → CNI dataplane → destination

---

## 7. Layer stack (where Day 26 + 28 sit)

```text
Layer 0   Node + containerd + runc + pause sandbox
Layer 1   CNI (Calico)           — can packets flow? pod gets IP?
Layer 2   NetworkPolicy          — WHO may talk to WHOM
Layer 3   Service + CoreDNS      — stable name → ClusterIP
Layer 4   Ingress / mesh         — edge + L7 / mTLS
```

DNS failure vs timeout: if Layer 1 broken, nothing above works. If Layer 1 OK but Layer 2 denies, `nslookup` returns IP but `curl` hangs.

---

## 8. Node troubleshooting commands

```bash
# Runtime / sandbox
crictl pods
crictl ps -a
crictl inspectp <pod-id>

# Network namespaces
sudo ip netns list
# often: cni-<hash> or visible via crictl

# Interfaces
ip link show
ip addr show

# From host into pod netns (advanced)
sudo nsenter -t $(crictl inspect <container-id> | jq .info.pid) -n ip addr
```

**Pod stuck `ContainerCreating`:** check kubelet logs, CNI plugin pods (Calico), image pull — often CNI ADD failed, not the app container.

---

## 9. CKA / interview Q&A

| Question | Answer |
|----------|--------|
| Does K8s include networking? | **No** — CNI plugin required |
| What is pause container? | Sandbox holding pod network namespace |
| Why one IP per pod? | All containers share pause's netns |
| kubelet → container? | CRI → containerd → runc (OCI) |
| Why dockershim removed? | CRI is the standard; Docker isn't the runtime anymore |
| Flannel vs Calico? | Flannel = connect; Calico = connect + enforce NetworkPolicy |
| runc role? | Creates container namespaces/cgroups; exits after start |

---

## 10. Lab checklist

- [x] Pod `ip addr` — eth0 + pod CIDR IP (`10.244.x.x`)
- [x] Node `ip netns list` — `cni-<uuid>` per pod
- [x] `lsns` — `/pause` sandboxes; `lsns -p <nginx-pid>` shares net with pause
- [x] Host `veth*` → `link-netns cni-...` (kind-net on Kind; Calico shows `cali*`)
- [ ] `crictl pods` / `crictl ps` on Kind node — find pause sandbox
- [ ] Two-container pod — `curl localhost` from sidecar to app
- [ ] Compare: Kind default CNI vs Day 26 Calico cluster

Full lab notes: [cni-practice-output.md](./cni-practice-output.md)

---

## 11. Lab findings — pause, namespaces, veth (Kind / kind-net)

### Inside vs outside the pod netns

| Where you run | `ip netns list` |
|---------------|-----------------|
| **Inside pod** | Empty — you're already in the pod netns |
| **On Kind node** | Lists `cni-<uuid>` — one per pod sandbox |

### Pause + app container (lsns proof)

```bash
lsns -p <nginx-pid>
# net, uts, ipc  →  shared with /pause (same pod sandbox)
# mnt, pid, cgroup  →  nginx's own
```

Each pod: **pause** holds netns → CNI assigns IP → app containers join → same Pod IP.

### kind-net vs Calico on the wire

| Cluster | Host interfaces |
|---------|-----------------|
| **Kind default** (`cka-cluster01`) | `veth*` + `kindnet` DaemonSet |
| **Calico** (Day 26 lab) | `cali*` + policy enforcement |

No `cali*` on Kind is **expected** — CNI plugin differs, not a misconfiguration.

### veth pair (from lab)

```text
Pod eth0 (10.244.1.11)  ←→  veth on host  ←→  kind-net  ←→  cluster
         @if21                  link-netns cni-...
```

Inspect peer from node:

```bash
ip netns exec cni-<uuid> ip link    # eth0 inside pod netns
ip link show | grep veth            # host side
```

---

## Reference

- [CNI specification](https://github.com/containernetworking/cni/blob/main/SPEC.md)
- [Container Runtime Interface (CRI)](https://kubernetes.io/docs/concepts/architecture/cri/)
- [Network plugins](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/)
- [Pod lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/)
