# CNI deep dive — lab output

Cluster: `cka-cluster01` (kind-net CNI) · Guest session: Saiyam Pathak

Full notes: [CNI-notes.md](./CNI-notes.md)

---

## Summary — what we proved

| Observation | Meaning |
|-------------|---------|
| Pod `eth0@if21` IP `10.244.1.11/24` | Pod has cluster IP from CNI |
| `ip netns list` **empty inside pod** | You're already inside the pod netns — list from **node** |
| Node `ip netns list` → `cni-<uuid>` | One netns per pod sandbox |
| `lsns` shows many `/pause` processes | Each pod's sandbox holding netns open |
| `lsns -p <nginx-pid>` shares **net/uts/ipc** with `/pause` | App container joined pause sandbox |
| nginx has own **mnt/pid/cgroup** | Only network (and uts/ipc) shared with pause |
| Host `veth*` → `link-netns cni-...` | veth pair connects pod to node (kind-net, not cali*) |
| No `cali*` interfaces | Expected on Kind — uses **kind-net**, not Calico |

---

## 1. Inside pod — pod IP and eth0

```bash
kubectl exec -it nginx-deploy-57b475c856-ptjbz -- ip addr
# eth0@if21: inet 10.244.1.11/24

kubectl exec -it nginx-deploy-... -- ip netns list
# (empty — already inside netns)
```

---

## 2. On worker node — netns and pause

```bash
docker exec -it cka-cluster01-worker bash
ip netns list
# cni-5cc14419-4392-b480-3ce2-bd03aff4072e
# cni-7ac03f44-1c82-8190-b40a-b2155a32bfc9
# ... one per pod on this node

lsns | grep pause | head -5
# 4026533863 net  2  1241 65535 /pause
# 4026533996 net 14  1474 65535 /pause
```

---

## 3. nginx shares pause network namespace

```bash
lsns -p 4546   # nginx master PID on worker
# net  → same as pause PID 1700
# uts, ipc → pause
# mnt, pid, cgroup → nginx own
```

```text
pause (PID 1700)  →  owns netns, holds IP
nginx (PID 4546)  →  joined pause netns → same Pod IP, localhost to sidecars
```

---

## 4. veth pairs on host (kind-net)

```bash
ip link show | grep veth
# veth9eb49426@... link-netns cni-5cc14419-...
# veth337b743d@... link-netns cni-7ac03f44-...

ip netns exec cni-536ce8b0-c630-31c9-5d07-892717a4cb66 ip link
# eth0@if21 inside that pod netns
```

```text
Pod eth0  ←veth pair→  vethXXXX on host  →  kind-net / bridge  →  other pods
```

**Note:** Calico clusters show `cali*` interfaces. Kind default uses `kindnet` DaemonSet + `veth*`.

---

## 5. Commands cheat sheet

```bash
# Enter Kind node
docker exec -it cka-cluster01-worker bash

ip netns list
ip link show | grep veth
lsns | grep pause
lsns -p <container-pid>
ip netns exec cni-<id> ip link

crictl pods && crictl ps    # sandbox + containers
```
