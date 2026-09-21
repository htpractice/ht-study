# Day 15 practice output — kc get pods -n affinity -o wide
# Captured after applying all three affinity deployments with node labels configured.
#
# Node labels used in lab:
#   cka-cluster01-worker:  disktype=ssd
#   cka-cluster01-worker2: disktype=ssd-nvme, nodetype=db
#   (no node with disktype=hdd)

```
NAME                                    READY   STATUS    RESTARTS   AGE     IP            NODE                    NOMINATED NODE   READINESS GATES
affinity-db-pod-67b89dd868-qgx6x        1/1     Running   0          2m55s   10.244.2.17   cka-cluster01-worker2   <none>           <none>
affinity-db-pod-67b89dd868-qpf6v        1/1     Running   0          2m55s   10.244.1.19   cka-cluster01-worker    <none>           <none>
affinity-db-pod-67b89dd868-vhzj4        1/1     Running   0          2m55s   10.244.2.18   cka-cluster01-worker2   <none>           <none>
affinity-no-pref-pod-648d4f849f-69zfz   1/1     Running   0          14s     10.244.1.20   cka-cluster01-worker    <none>           <none>
affinity-no-pref-pod-648d4f849f-6gt2q   1/1     Running   0          14s     10.244.2.19   cka-cluster01-worker2   <none>           <none>
affinity-no-pref-pod-648d4f849f-pxr7f   1/1     Running   0          14s     10.244.2.20   cka-cluster01-worker2   <none>           <none>
affinity-pod-85668cf4cd-f5pbb           1/1     Running   0          9m25s   10.244.1.17   cka-cluster01-worker    <none>           <none>
affinity-pod-85668cf4cd-fmlwh           1/1     Running   0          9m25s   10.244.1.16   cka-cluster01-worker    <none>           <none>
affinity-pod-85668cf4cd-gnrkz           1/1     Running   0          9m25s   10.244.1.18   cka-cluster01-worker    <none>           <none>
```

## Interpretation

| Deployment | Affinity | Result |
|------------|----------|--------|
| **affinity-pod** | Required `disktype In [ssd]` | 3/3 on **worker** only — only node with exact label |
| **affinity-db-pod** | Preferred `nodetype In [db]` | 2/3 on **worker2** (has nodetype=db), 1/3 on worker |
| **affinity-no-pref-pod** | Preferred `disktype In [hdd]` | Spread across both — no HDD nodes, soft rule ignored |
