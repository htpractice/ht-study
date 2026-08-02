# Day 27 — CoreDNS (cluster DNS)

How pods **resolve Service names** to ClusterIPs — connects **Day 10** (FQDN) and **Day 26** (who can reach whom after DNS resolves).

---

## 1. Mental Model

```text
Pod wants backend-svc.backend-app.svc.cluster.local
        │
        ▼
/etc/resolv.conf  →  nameserver 10.96.0.10 (kube-dns ClusterIP)
        │
        ▼
CoreDNS (kube-system)  →  returns Service ClusterIP
        │
        ▼
NetworkPolicy / routing  →  allows or blocks (Day 26)
```

**DNS answers WHAT IP. NetworkPolicy answers MAY I CONNECT.**

---

## 2. CoreDNS Components

| Object | Namespace | Role |
|--------|-----------|------|
| Deployment/DaemonSet **coredns** | `kube-system` | DNS server pods |
| Service **kube-dns** (name legacy) | `kube-system` | Stable ClusterIP (usually `10.96.0.10`) |
| ConfigMap **coredns** | `kube-system` | `Corefile` — DNS zones and forward rules |

```bash
kc get pods,svc,cm -n kube-system | grep -E 'dns|coredns'
kc get cm coredns -n kube-system -o yaml
```

---

## 3. DNS Names (memorize for CKA)

| Query | Resolves to |
|-------|-------------|
| `svc-name` | Same namespace only |
| `svc-name.namespace` | Cross-namespace (short) |
| `svc-name.namespace.svc.cluster.local` | **FQDN** (always works cross-ns) |
| `pod-ip-with-dashes.namespace.pod.cluster.local` | Pod IP (if enabled) |

**Cluster domain default:** `cluster.local`  
**Service segment:** `.svc`  
**Pod segment:** `.pod` (optional)

From Day 26 lab:
```bash
# same cluster, different namespaces
database-svc.database-app.svc.cluster.local:3306
backend-svc.backend-app.svc.cluster.local:80
```

---

## 4. Inside a Pod

```bash
kc run dns-test --image=busybox:1.36 --restart=Never -it --rm -- sh
# cat /etc/resolv.conf
# nslookup kubernetes.default
# nslookup backend-svc.backend-app.svc.cluster.local
# wget -qO- http://backend-svc.backend-app.svc.cluster.local
```

| File | Typical content |
|------|-----------------|
| `/etc/resolv.conf` | `nameserver 10.96.0.10`, `search default.svc.cluster.local svc.cluster.local cluster.local` |
| `ndots:5` | Short names need enough dots or get search suffixes appended |

---

## 5. Corefile Basics (ConfigMap)

```text
.:53 {
    errors
    health
    kubernetes cluster.local in-addr.arpa ip6.arpa {
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
    }
    forward . /etc/resolv.conf
    cache 30
}
```

| Block | Meaning |
|-------|---------|
| `kubernetes cluster.local` | Answer Service/Pod DNS for in-cluster names |
| `forward . /etc/resolv.conf` | External names → node upstream DNS |
| `pods insecure` | Pod-by-IP DNS records (when enabled) |

**CKA:** edit ConfigMap → rollout CoreDNS or wait for mount sync (know `kubectl edit cm coredns -n kube-system`).

---

## 6. Troubleshooting Flow

```text
1. DNS or network?
   nslookup svc.ns.svc.cluster.local  → NXDOMAIN = DNS
                                       → IP returned but timeout = NetworkPolicy/routing (Day 26)

2. CoreDNS running?
   kc get pods -n kube-system -l k8s-app=kube-dns

3. Service/endpoints exist?
   kc get svc,endpoints -n <ns>

4. CoreDNS logs
   kc logs -n kube-system -l k8s-app=kube-dns
```

---

## 7. Day 26 Tie-in

| Symptom | Likely layer |
|---------|--------------|
| `Could not resolve host` | **DNS** (CoreDNS, wrong name, wrong search path) |
| `Connected` / IP shown but hang/timeout | **NetworkPolicy** or app not listening |
| Works with FQDN, not short name | **search domain** / wrong namespace in short name |

---

## 8. ECS Parallel

| K8s CoreDNS | ECS |
|-------------|-----|
| `svc.ns.svc.cluster.local` | Service Connect / Cloud Map name |
| kube-dns ClusterIP | VPC DNS resolver for service discovery |
| Corefile custom zones | Route53 private hosted zones |

---

## 9. CKA Exam Tips

```bash
kubectl explain configmap
kubectl get cm coredns -n kube-system -o yaml
kubectl run tmp --image=busybox:1.36 -it --rm -- nslookup kubernetes.default
```

- CoreDNS = **`kube-system`**, Service name often still **`kube-dns`**
- Know FQDN format: `<svc>.<ns>.svc.cluster.local`
- Custom DNS / stub domains → edit **coredns** ConfigMap
- Debug pod: `busybox` + `nslookup` / `wget`

---

## 10. Lab Checklist (fill as you go)

- [ ] Inspect CoreDNS pods + Service in kube-system
- [ ] Read `coredns` ConfigMap Corefile
- [ ] `nslookup` / `dig` from test pod — `kubernetes.default`
- [ ] Cross-ns lookup — Day 26 services
- [ ] Note `/etc/resolv.conf` search line
- [ ] (If course covers) edit Corefile / custom domain — paste output below

### Practice output

```text
(paste commands + output here — then ask to polish & push)
```

---

## Reference

- [DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- [Customizing DNS Service](https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/)
- [Debugging DNS Resolution](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/)
