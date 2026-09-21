# CNI — Quick Read

Full notes: [CNI-notes.md](./CNI-notes.md) · Lab: [cni-practice-output.md](./cni-practice-output.md)

---

## Lifecycle (30 sec)

```text
kubectl apply → API → scheduler → kubelet
  → pause sandbox (netns) → CNI ADD (IP + veth) → app containers join netns
kubelet → CRI → containerd → runc (creates, then exits)
```

## Pause container

- Image: `registry.k8s.io/pause:3.x`
- Holds **network namespace** open — app containers share Pod IP + localhost
- `lsns -p <app-pid>` → net/uts/ipc shared with `/pause`

## CNI

- K8s has **no** built-in pod network — plugin required
- Kind default: **kind-net** (`veth*`, `kindnet` DaemonSet)
- Calico (Day 26): `cali*` + NetworkPolicy enforcement

## veth

```text
Pod eth0  ←→  veth on host (link-netns cni-...)  ←→  cluster
```

## Layers

```text
CNI → NetworkPolicy → CoreDNS/Service → Ingress
```

## Node debug

```bash
docker exec -it cka-cluster01-worker bash
ip netns list
lsns | grep pause
lsns -p <nginx-pid>
ip link show | grep veth
crictl pods && crictl ps
```

**Inside pod:** `ip netns list` is empty — you're already in the netns.

## Interview one-liner

> Pause owns the netns; CNI wires the veth; CoreDNS names the Service — three different layers.
