# Day 23 practice output — User ht + RoleBinding

## Day 21 revision — cert expired

Re-ran Day 21 openssl + CSR approve flow (lab cert = 24h TTL). Updated `ht.crt` in kubeconfig before RBAC lab. Formal renewal covered in later course videos.

## Apply RBAC (admin context)

```bash
kc apply -f rbac-ns.yaml
kc apply -f read-role.yaml
kc apply -f rolebinding.yaml
```

## Kubeconfig — user ht context

```bash
kc config set-context ht --cluster=kind-cka-cluster01 --user=ht
kc config use-context ht
```

### Traps hit

```bash
kc get contexts                    # error — not a resource
kc config get-contexts             # correct

kc config use-contexts ht          # error — unknown command
kc config use-context ht             # correct — Switched to context "ht"
```

## RBAC behavior as user ht

```bash
kc get po
# Error from server (Forbidden): User "ht" cannot list resource "pods" in namespace "default"

kc get po -n rbac
# No resources found in rbac namespace.   ← SUCCESS (allowed, just empty)

kc run pod-ht --image=nginx
# Forbidden: User "ht" cannot create resource "pods" in namespace "default"
```

## auth can-i (admin context, faster check)

```bash
kc auth can-i list pods --as=ht -n rbac      # yes
kc auth can-i list pods --as=ht -n default   # no
kc auth can-i create pods --as=ht -n rbac    # no
```

## What this proves

| Check | Result |
|-------|--------|
| Auth (cert) works — API knows User ht | ✓ |
| No RoleBinding in default → Forbidden | ✓ |
| RoleBinding in rbac → list pods allowed | ✓ |
| create not in Role verbs → Forbidden | ✓ |
| RoleBinding scope ≠ cluster-wide | ✓ |

## Switch back to admin

```bash
kc config use-context kind-cka-cluster01
```
