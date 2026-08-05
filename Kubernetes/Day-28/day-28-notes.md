# Day 28 — DNS (Internet fundamentals + CoreDNS)

**Quick read:** [quick-read.md](./quick-read.md) · Lab: [practical-output.md](./practical-output.md)

Connects **Day 10** (FQDN / namespaces) and **Day 26** (DNS resolves IP → NetworkPolicy allows or blocks traffic).

---

# Part 1 — Internet DNS (foundations)

---

## 1. Mental Model

```text
Human name (google.com)  →  DNS  →  IP address (142.250.x.x)  →  TCP connection
```

**Interview one-liner:** DNS is the internet phonebook — names for humans, IPs for machines.

---

## 2. Why DNS exists

Computers connect via **IP addresses**. People use **domain names**. DNS translates between them so you don't hard-code IPs that change.

Without DNS you'd bookmark `142.250.80.46` instead of `google.com`.

---

## 3. Resolution hierarchy

```text
Browser/OS cache
    ↓ miss
Recursive resolver (ISP / 8.8.8.8)
    ↓
Root servers (13 logical, anycast globally)  →  "ask .com servers"
    ↓
TLD servers (.com, .dev, .org)
    ↓
Authoritative name server for your domain  →  returns A/CNAME/etc.
```

| Layer | Role |
|-------|------|
| **Root** | Points to TLD servers — doesn't know every website |
| **TLD** | Manages `.com`, `.dev`, etc. |
| **Authoritative** | Your domain's truth — where you set A/CNAME/MX records |

**Anycast:** 13 logical root IPs, many physical servers worldwide — same IP, nearest server answers.

---

## 4. Caching (performance)

DNS uses caching at every layer to avoid repeated lookups:

```text
Browser cache → OS cache → Router → ISP resolver → authoritative
```

TTL (time-to-live) on each record controls how long a cached answer is trusted.

---

## 5. Common record types

| Record | Purpose | Example |
|--------|---------|---------|
| **A** | Domain → **IPv4** | `example.com` → `1.2.3.4` |
| **AAAA** | Domain → **IPv6** | `example.com` → `2001:db8::1` |
| **CNAME** | Alias → **another domain** (not IP) | `www` → `example.vercel.app` |
| **MX** | Mail routing | priority + mail server hostname |
| **NS** | Delegates subdomain to another DNS server | host your own DNS zone |

### A vs CNAME (high yield)

| | **A record** | **CNAME** |
|---|--------------|-----------|
| Points to | **IP address** | **Another hostname** |
| IP changes | You **update manually** | Target domain's A record changes — alias still works |
| Use when | You control the IP | SaaS/CDN (Vercel, Cloudflare, ALB) — provider owns IP |
| Root domain `@` | **Yes** | Often **not allowed** at apex (use ALIAS/ANAME or A) |

**Why CNAME for Vercel/Cloudflare:** provider IP changes; your domain points to their hostname, they manage the IP.

**CKA note:** exam focuses on **in-cluster** DNS (Part 2). Internet record types = background for interviews and troubleshooting external names.

---

## 6. Local overrides (troubleshooting)

| File | Purpose |
|------|---------|
| `/etc/hosts` | Manual name → IP on **this machine** (bypasses DNS) |
| `/etc/resolv.conf` | Which DNS servers this machine uses |

```text
# /etc/hosts example
127.0.0.1   localhost
192.168.1.10 myapp.local
```

Same idea in pods: `/etc/resolv.conf` points to cluster DNS (Part 2).

---

## 7. Internet DNS — quick Q&A

| Question | Answer |
|----------|--------|
| A vs CNAME? | A → IP directly; CNAME → alias to another name |
| AAAA? | IPv6 version of A |
| Root servers? | 13 logical; delegate to TLD — not a full phonebook |
| Authoritative server? | Holds actual records for your domain |
| When CNAME? | Outsourced hosting where provider IP may change |
| Why caching? | Billions of queries — avoid hitting root/authoritative every time |

---

# Part 2 — CoreDNS (Kubernetes cluster DNS)

---

## 1. Mental Model

```text
Pod wants backend-svc.backend-app.svc.cluster.local
        │
        ▼
/etc/resolv.conf  →  nameserver 10.96.0.10 (kube-dns Service ClusterIP)
        │
        ▼
CoreDNS pods (kube-system)  →  returns Service ClusterIP
        │
        ▼
NetworkPolicy / routing  →  allows or blocks (Day 26)
```

**Interview one-liner:** CoreDNS resolves **Service names → ClusterIP**. NetworkPolicy decides if traffic is allowed after that.

**DNS answers WHAT IP. NetworkPolicy answers MAY I CONNECT.**

---

## 2. CoreDNS vs kube-dns (naming trap)

| Name | What it actually is |
|------|---------------------|
| **CoreDNS** | DNS **software** — Deployment pods in `kube-system` |
| **Service `kube-dns`** | Legacy **Service name** — stable ClusterIP pods use as nameserver |
| **ConfigMap `coredns`** | **Corefile** config — zones, forward rules, plugins |

```bash
kubectl get pods,svc,cm -n kube-system | grep -E 'dns|coredns'
kubectl get svc kube-dns -n kube-system
kubectl get cm coredns -n kube-system -o yaml
```

Scale CoreDNS if needed (course demo):

```bash
kubectl scale deployment coredns -n kube-system --replicas=3
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

---

## 3. DNS names (memorize for CKA)

| Query | Resolves to |
|-------|-------------|
| `svc-name` | Same namespace only |
| `svc-name.namespace` | Cross-namespace (short form) |
| `svc-name.namespace.svc.cluster.local` | **FQDN** — always works cross-ns |
| `<pod-ip-dashes>.namespace.pod.cluster.local` | Pod IP (if `pods` plugin enabled) |

**Cluster domain default:** `cluster.local`  
**Service segment:** `.svc`  
**Pod segment:** `.pod` (optional)

From [Day 10](../Day-10/day-10-notes.md) / [Day 26](../Day-26/day-26-notes.md):

```bash
database-svc.database-app.svc.cluster.local:3306
backend-svc.backend-app.svc.cluster.local:80
```

Short name `database-svc` only works **inside `database-app` namespace**.

---

## 4. Inside a pod

Every pod gets `/etc/resolv.conf` injected automatically:

```bash
kubectl run dns-test --image=busybox:1.36 --restart=Never -it --rm -- sh
# cat /etc/resolv.conf
# nslookup kubernetes.default
# nslookup backend-svc.backend-app.svc.cluster.local
# wget -qO- http://backend-svc.backend-app.svc.cluster.local
```

| Field | Typical content |
|-------|-----------------|
| `nameserver` | kube-dns ClusterIP (e.g. `10.96.0.10`) |
| `search` | `default.svc.cluster.local svc.cluster.local cluster.local` |
| `ndots:5` | Short names get search suffixes appended |

**search line:** `backend-svc` in `backend-app` ns → tries `backend-svc.backend-app.svc.cluster.local` automatically.

---

## 5. Corefile (ConfigMap)

CoreDNS behavior = **ConfigMap `coredns`** mounted into CoreDNS pods:

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
| `kubernetes cluster.local` | Answer in-cluster Service/Pod DNS |
| `forward . /etc/resolv.conf` | External names (google.com) → node upstream DNS |
| `pods insecure` | Pod DNS records by IP (when enabled) |
| `cache 30` | Cache successful answers 30 seconds |

**CKA:** customize DNS → `kubectl edit cm coredns -n kube-system` → CoreDNS picks up mounted config.

---

## 6. Troubleshooting flow

```text
1. DNS or network?
   nslookup svc.ns.svc.cluster.local
     → NXDOMAIN / no server     = DNS problem
     → IP returned, then timeout = NetworkPolicy / routing / app (Day 26)

2. CoreDNS running?
   kubectl get pods -n kube-system -l k8s-app=kube-dns

3. Service + endpoints exist?
   kubectl get svc,endpoints -n <ns>

4. CoreDNS logs
   kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50
```

### Cloud / CNI gotchas (course notes)

| Issue | Fix |
|-------|-----|
| CoreDNS pods not starting | Check CNI (Calico) is healthy — nodes Ready |
| AWS EC2 nodes, DNS fails | Disable **source/destination check** on worker instances |
| NetworkPolicy too strict | DNS may need egress to `kube-system` / kube-dns Service |

---

## 7. Day 26 tie-in

| Symptom | Likely layer |
|---------|--------------|
| `Could not resolve host` | **DNS** — wrong name, CoreDNS down, search path |
| IP shown but hang/timeout | **NetworkPolicy** or app not listening |
| FQDN works, short name fails | Wrong namespace / **search domain** |

Stack from Day 26:

```text
CNI (Calico)     → packets can flow
NetworkPolicy    → who may connect
CoreDNS          → name → ClusterIP
Service          → stable endpoint
```

---

## 8. ECS / platform parallel

| K8s CoreDNS | ECS / AWS |
|-------------|-----------|
| `svc.ns.svc.cluster.local` | Service Connect / Cloud Map name |
| kube-dns ClusterIP | VPC DNS resolver + service discovery |
| Corefile custom zones | Route53 private hosted zones |
| `forward . /etc/resolv.conf` | External DNS for outbound lookups |

---

## 9. CKA / interview Q&A

| Question | Answer |
|----------|--------|
| What resolves pod Service names? | **CoreDNS** in `kube-system` |
| Service name vs FQDN? | Short name = same ns only; FQDN = cross-ns |
| kube-dns vs CoreDNS? | kube-dns = Service name; CoreDNS = actual DNS pods |
| Pod DNS config? | Auto-injected `/etc/resolv.conf` → kube-dns IP |
| Custom cluster DNS? | Edit **coredns** ConfigMap Corefile |
| DNS vs NetworkPolicy? | DNS = resolve IP; NetPol = allow/deny packets |
| Debug command? | `kubectl run ... busybox -- nslookup <fqdn>` |

### Exam commands

```bash
kubectl explain configmap
kubectl get cm coredns -n kube-system -o yaml
kubectl run tmp --image=busybox:1.36 -it --rm --restart=Never -- nslookup kubernetes.default
kubectl get svc kube-dns -n kube-system
```

---

## 10. Lab results (verified on `cka-cluster01`)

| Test | Result |
|------|--------|
| `curl nodeport-svc` / `clusterip-svc` from **default** pod | **OK** — short name (same ns) |
| `curl php-apache` from **default** pod | **FAIL** — NXDOMAIN |
| `curl php-apache.hpa-vpa.svc.cluster.local` | **OK** — FQDN cross-ns |

Full output: [practical-output.md](./practical-output.md)

### Lab checklist

**Internet DNS (theory):**
- [x] Explain A vs CNAME with Vercel/Cloudflare example
- [x] Trace resolution: browser → resolver → root → TLD → authoritative

**CoreDNS (hands-on):**
- [x] Same-ns Service access with short name (`nodeport-svc`, `clusterip-svc`)
- [x] Cross-ns requires FQDN (`php-apache.hpa-vpa.svc.cluster.local`)
- [ ] Inspect CoreDNS pods + `kube-dns` Service in `kube-system`
- [ ] Read `coredns` ConfigMap Corefile
- [ ] From test pod: `cat /etc/resolv.conf`
- [ ] `nslookup kubernetes.default`
- [ ] Cross-ns lookup — Day 26 services (`database-svc.database-app.svc.cluster.local`)
- [ ] (Optional) scale CoreDNS replicas; edit Corefile stub domain

---

## Reference

### Internet DNS
- [How DNS works (Cloudflare)](https://www.cloudflare.com/learning/dns/what-is-dns/)

### Kubernetes DNS
- [DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- [Customizing DNS Service](https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/)
- [Debugging DNS Resolution](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/)
