# Day 28 — DNS lab output

Cluster: `cka-cluster01` · Context: CoreDNS + same-namespace vs cross-namespace Service DNS

---

## Summary

| Test | Result |
|------|--------|
| `curl nodeport-svc` from pod in **default** | **OK** — short name resolves (same namespace) |
| `curl clusterip-svc` from pod in **default** | **OK** |
| `curl multi-cont-svc` from **default** | **FAIL** — `Could not resolve host` |
| `curl php-apache` from **default** | **FAIL** |
| `curl php-apache.hpa-vpa.svc.cluster.local` | **OK** — FQDN required cross-namespace |

**Takeaway:** short Service name = same namespace only. Cross-ns → `<svc>.<namespace>.svc.cluster.local`.

---

## 1. Same namespace — short name works

```bash
kubectl get svc
# clusterip-svc   ClusterIP   10.96.130.115   80/TCP
# nodeport-svc    NodePort    10.96.63.213    80:31593/TCP

kubectl exec -it nginx-deploy-57b475c856-ptjbz -- curl -s nodeport-svc | head -3
# Welcome to nginx!

kubectl exec -it pod-test -- curl -s clusterip-svc | head -3
# Welcome to nginx!
```

CoreDNS `search` line appends `default.svc.cluster.local` → `nodeport-svc` resolves.

---

## 2. Cross namespace — short name fails, FQDN works

```bash
kubectl exec -it pod-test -- curl multi-cont-svc
# curl: (6) Could not resolve host: multi-cont-svc

kubectl exec -it pod-test -- curl php-apache
# curl: (6) Could not resolve host: php-apache

kubectl exec -it pod-test -- curl php-apache.hpa-vpa.svc.cluster.local
# OK!
```

| Service | Namespace | From `default` pod |
|---------|-----------|-------------------|
| `php-apache` | `hpa-vpa` | Need `php-apache.hpa-vpa.svc.cluster.local` |
| `multi-cont-svc` | `multicon` | Need FQDN (not tested here but same rule) |

---

## Full command log (reference)

<details>
<summary>Same-ns curl output</summary>

```text
kc exec -it nginx-deploy-57b475c856-ptjbz -- curl nodeport-svc   → nginx HTML
kc exec -it pod-test -- curl nodeport-svc                        → nginx HTML
kc exec -it pod-test -- curl clusterip-svc                       → nginx HTML
```

</details>

<details>
<summary>Cross-ns failures + FQDN success</summary>

```text
kc exec -it pod-test -- curl multi-cont-svc
curl: (6) Could not resolve host: multi-cont-svc

kc exec -it pod-test -- curl php-apache
curl: (6) Could not resolve host: php-apache

kc exec -it pod-test -- curl php-apache.hpa-vpa.svc.cluster.local
OK!
```

</details>
