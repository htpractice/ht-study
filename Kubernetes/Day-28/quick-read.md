# Day 28 — DNS Quick Read

Full notes: [day-28-notes.md](./day-28-notes.md) · Lab: [practical-output.md](./practical-output.md)

---

## Internet DNS (30 sec)

```text
name → DNS → IP    A record = name→IP    CNAME = alias→another name
```

| Record | Points to |
|--------|-----------|
| **A** | IPv4 |
| **CNAME** | Another hostname (Vercel/Cloudflare) |
| **AAAA** | IPv6 |

---

## K8s CoreDNS (60 sec)

```text
Pod → /etc/resolv.conf → kube-dns ClusterIP → CoreDNS → Service ClusterIP
DNS = WHAT IP    NetworkPolicy = MAY I CONNECT (Day 26)
```

| Query | Works when |
|-------|------------|
| `svc-name` | **Same namespace** |
| `svc-name.other-ns` | Cross-ns short form |
| `svc-name.other-ns.svc.cluster.local` | **FQDN — always** |

**Naming trap:** CoreDNS = pods · Service = still called `kube-dns`

### Lab proved

```bash
# default ns pod → OK
curl nodeport-svc
curl clusterip-svc

# default ns pod → FAIL without FQDN
curl php-apache
curl php-apache.hpa-vpa.svc.cluster.local   # OK
```

### Debug

```bash
kubectl get pods,svc -n kube-system | grep -E 'dns|coredns'
kubectl get cm coredns -n kube-system -o yaml
kubectl exec -it <pod> -- cat /etc/resolv.conf
kubectl exec -it <pod> -- nslookup kubernetes.default
```

### Exam traps

1. Short name cross-namespace → NXDOMAIN
2. IP from nslookup but timeout → NetPol/routing, not DNS
3. Edit **coredns** ConfigMap for custom DNS / forward rules
