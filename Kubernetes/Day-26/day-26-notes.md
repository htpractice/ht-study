# Day 26 — Network Policies (Calico + 3-tier lab)

Restrict pod traffic with **NetworkPolicy** — requires a CNI that enforces policies (**Calico**, Cilium). **Kind-net / Flannel = no enforcement.**

---

## 1. Mental Model

```text
Default K8s: all pods can talk to all pods (flat network)
NetworkPolicy on database pods: default DENY ingress → allow ONLY listed sources
```

**Goal:** backend → database ✓ | frontend → database ✗

### Why learn this **before** DNS, Ingress, and service mesh

```text
Layer / topic          What it controls
─────────────────────────────────────────────────────────
Pod network (CNI)      Can packets flow at all? (Calico routes)
NetworkPolicy  ← YOU   WHO may talk to WHOM (L3/L4 firewall)
Service + CoreDNS      Stable name → ClusterIP (discovery)
Ingress                External HTTP/S → in-cluster Service (L7 edge)
Service mesh           mTLS + L7 policy between services (Istio/Linkerd)
```

NetworkPolicy is **east-west security at the pod level**. Without it, Ingress and mesh rules still leave internal pods wide open. CKA tests standard `NetworkPolicy` heavily; mesh is awareness.

**Official docs (read in this order):**

1. [Network Policies — concepts](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
2. [Declare network policy](https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/) — hands-on task
3. [NetworkPolicy API reference](https://kubernetes.io/docs/reference/kubernetes-api/policy-resources/network-policy-v1/)

---

## 2. Cluster Setup (Kind + Calico)

| Step | Command |
|------|---------|
| Create cluster (no default CNI) | `kind create cluster --config network-kind.yaml --name cka-nw-cluster01` |
| Install Calico | `kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/calico.yaml` |
| Wait for nodes Ready | `kubectl get nodes -w` |

`network-kind.yaml` sets `disableDefaultCNI: true` — nodes stay NotReady until Calico runs.

**CKA / exam:** standard `networking.k8s.io/v1` NetworkPolicy + Calico/Cilium — not `projectcalico.org/v3` CRDs unless specified.

---

## 3. Three-Tier App

| Namespace | App | Service DNS |
|-----------|-----|-------------|
| `frontend-app` | frontend | `frontend-svc.frontend-app.svc.cluster.local` |
| `backend-app` | backend | `backend-svc.backend-app.svc.cluster.local` |
| `database-app` | database (mysql) | `database-svc.database-app.svc.cluster.local:3306` |

Apply: `namespace.yaml` → `frontend.yaml` → `backend.yaml` → `database.yaml`

**Cross-ns DNS:** use FQDN (Day 10) — short names like `backend-svc` fail outside same namespace.

---

## 4. Official docs — AND vs OR (super important — read carefully)

The [Network Policies concept page](https://kubernetes.io/docs/concepts/services-networking/network-policies/) shows **two different YAML shapes**. Mixing them up breaks labs (this Day 26 bug).

### Pattern A — **AND** (one `- from` item, both selectors)

From the docs — *"A single to/from entry that specifies both namespaceSelector and podSelector selects particular Pods within particular namespaces."*

```yaml
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        user: alice
    podSelector:              # SAME list item — indented under same dash
      matchLabels:
        role: client
```

**Meaning:** only **client** pods in namespaces labeled **`user: alice`**.

**Our lab equivalent:** backend pods in `backend-app`:

```yaml
- namespaceSelector:
    matchLabels:
      name: backend-app
  podSelector:
    matchLabels:
      app: backend
```

---

### Pattern B — **OR** (multiple `- from` items)

From the same docs — [example policy `test-network-policy`](https://kubernetes.io/docs/concepts/services-networking/network-policies/#default-deny-all-ingress-traffic):

```yaml
ingress:
- from:
  - ipBlock:
      cidr: 172.17.0.0/16
      except:
      - 172.17.1.0/24
  - namespaceSelector:
      matchLabels:
        project: myproject
  - podSelector:
      matchLabels:
        role: frontend
  ports:
  - protocol: TCP
    port: 6379
```

**Meaning:** allow if **any one** matches:

| Separate `- from` item | Who gets in |
|----------------------|-------------|
| `ipBlock` | That CIDR range |
| `namespaceSelector` alone | **All pods** in ns labeled `project: myproject` |
| `podSelector` alone | **frontend** pods in **policy's namespace** only |

This is **OR across list items** — different use case than "backend in another namespace."

---

### What we wrote by mistake (looked like Pattern A, was Pattern B)

```yaml
# Two dashes under from = OR (like Pattern B) — NOT AND
ingress:
- from:
  - podSelector:
      matchLabels:
        app: backend              # backend pods in database-app → none
  - namespaceSelector:
      matchLabels:
        name: backend-app         # label missing anyway
```

We **thought** "backend + backend-app namespace" but YAML parsed as **either** branch. Neither matched → **default deny everything** (backend included).

---

### Memory hook (exam + on-call)

```text
One "-" under from  +  namespaceSelector AND podSelector same block  =  AND
Multiple "-" lines under from                                       =  OR
```

```bash
kubectl explain networkpolicy.spec.ingress.from
kubectl explain networkpolicy.spec.ingress.from.namespaceSelector
```

---

## 5. NetworkPolicy — The Three Traps (why the lab failed)

### Trap 1 — `podSelector` alone = same namespace only

```yaml
# WRONG — looks for app=backend pods INSIDE database-app (none exist)
- podSelector:
    matchLabels:
      app: backend
```

Backend pods live in **`backend-app`**, not `database-app`.

### Trap 2 — two `from` entries = **OR**, not AND

```yaml
# WRONG — neither branch matches backend correctly → implicit deny all
from:
- podSelector: { app: backend }      # wrong ns
- namespaceSelector: { name: backend-app }  # all pods in ns, but label missing
```

### Trap 3 — namespace **name** ≠ namespace **label**

```yaml
namespaceSelector:
  matchLabels:
    name: backend-app   # namespace must HAVE this label
```

Check: `kubectl get ns backend-app --show-labels`  
Kind adds `kubernetes.io/metadata.name=backend-app` automatically — **not** `name=backend-app` unless you label it.

### Correct policy (`network-policy.yaml`)

```yaml
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        name: backend-app
    podSelector:              # AND — both must match
      matchLabels:
        app: backend
  ports:
  - protocol: TCP
    port: 3306
```

One `from` block, **both** selectors → traffic from backend pods in backend-app namespace only.

---

## 6. Apply and Test

```bash
kubectl label namespace backend-app name=backend-app --overwrite
kubectl apply -f network-policy.yaml

# TEST FROM BACKEND (should succeed)
kubectl exec -n backend-app deploy/backend -- \
  nc -zv database-svc.database-app.svc.cluster.local 3306

# TEST FROM FRONTEND (should timeout/fail)
kubectl exec -n frontend-app deploy/frontend -- \
  nc -zv database-svc.database-app.svc.cluster.local 3306
```

**Common mistake:** testing DB from **frontend** and expecting success — policy should **block** that.

---

## 7. Calico vs Kubernetes NetworkPolicy

| | `networking.k8s.io/v1` NetworkPolicy | `projectcalico.org/v3` NetworkPolicy |
|---|----------------------------------------|--------------------------------------|
| **Tool** | `kubectl apply` | `kubectl calico` / Calico API |
| **CKA** | **Yes** | No (unless course extra) |
| **Enforcement** | Calico CNI implements standard NP | Native Calico CRD |

Use **`network-policy.yaml`** for CKA — Calico as CNI enforces it.

---

## 8. Default Deny Behavior

When a NetworkPolicy selects database pods (`podSelector: app: database`):

- All **other** ingress to those pods is **denied**
- Only rules in `ingress` are allowed
- Egress unchanged unless you add `policyTypes: [Egress]` + rules

---

## 9. CKA Exam Tips

```bash
kubectl explain networkpolicy.spec.ingress.from
kubectl get netpol -n database-app
kubectl describe netpol allow-traffic-from-backend -n database-app
```

- Policy applies to pods matching `spec.podSelector` in policy's namespace
- `from` items OR'd; `namespaceSelector` + `podSelector` in **same** item AND'd
- Need CNI support — mention Calico/Cilium if asked

---

## 10. Interview Q&A

| Question | Answer |
|----------|--------|
| Does kind-net enforce NetworkPolicy? | **No** — need Calico, Cilium, Weave (legacy) |
| namespaceSelector matches name? | **No** — matches **labels** on Namespace object |
| podSelector without namespaceSelector? | Only pods in **policy's namespace** |
| Frontend can't reach DB after policy? | **Expected** if only backend allowed |
| AND vs OR in `from`? | Same list item = AND; multiple items = OR — [docs](https://kubernetes.io/docs/concepts/services-networking/network-policies/) |
| NetworkPolicy vs Ingress vs mesh? | NP = pod firewall east-west; Ingress = north-south HTTP; mesh = mTLS + L7 between services |

---

## Reference

- [Network Policies — concepts (AND/OR examples)](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Declare network policy — task](https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/)
- [NetworkPolicy v1 API](https://kubernetes.io/docs/reference/kubernetes-api/policy-resources/network-policy-v1/)
- [Calico on Kind](https://projectcalico.docs.tigera.io/getting-started/kubernetes/kind)
