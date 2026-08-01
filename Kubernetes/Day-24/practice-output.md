# Day 24 practice output — ClusterRole node-reader for user ht

## Prerequisites

Day 21 cert re-issued (ht.key + ht.crt must match — see Day 23 notes if `private key does not match public key`).

## Apply (admin)

```bash
kc config use-context kind-cka-cluster01
kc apply -f node-reader-role.yaml
kc apply -f cluster-node-reader-binding.yaml
```

## As user ht

```bash
kc config use-context ht
kc get nodes
```

```
NAME                          STATUS   ROLES           AGE   VERSION
cka-cluster01-control-plane   Ready    control-plane   25d   v1.36.1
cka-cluster01-worker          Ready    <none>          25d   v1.36.1
cka-cluster01-worker2         Ready    <none>          25d   v1.36.1
```

## Least privilege — still Forbidden

```bash
kc get pods
# Forbidden: User "ht" cannot list pods in namespace "default"

kc delete node cka-cluster01-worker
# Forbidden: User "ht" cannot delete resource "nodes" at the cluster scope
```

## Cluster-scoped describe

```bash
kc describe clusterrole node-reader
# nodes [get list watch]

kc describe clusterrole node-reader -n rbac   # -n ignored — still shows same role
```

## Trap

```bash
kc list nodes    # error: unknown command "list" — use get
```

## What this proves

| Check | Result |
|-------|--------|
| ClusterRole grants node read cluster-wide | ✓ get nodes |
| delete not in verbs → Forbidden | ✓ |
| pods in default still Forbidden (Day 23 scope separate) | ✓ |
| ClusterRole works without `-n` | ✓ |

## Switch back

```bash
kc config use-context kind-cka-cluster01
```
