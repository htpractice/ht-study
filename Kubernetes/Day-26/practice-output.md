- Building networking cluster without default kindnet cni.

53:55 +0530   KubeletNotReady              container runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:Network plugin returns error: cni plugin not initialized

➜  Day-26 git:(cka-2026-study) ✗ kc get nodes
NAME                             STATUS     ROLES           AGE     VERSION
cka-nw-cluster01-control-plane   NotReady   control-plane   2m16s   v1.36.1
cka-nw-cluster01-worker          NotReady   <none>          2m2s    v1.36.1
cka-nw-cluster01-worker2         NotReady   <none>          2m2s    v1.36.1


- Adding the calico cni
➜  Day-26 git:(cka-2026-study) ✗ kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/calico.yaml

- new ns added for 3 tier
➜  Day-26 git:(cka-2026-study) ✗ kc get ns
NAME                 STATUS   AGE
backend-app          Active   2m27s
database-app         Active   2m27s
default              Active   28m
frontend-app         Active   2m27s
kube-node-lease      Active   28m
kube-public          Active   28m
kube-system          Active   28m
local-path-storage   Active   28m
weave-net            Active   2m27s


- Created 3 tier

➜  Day-26 git:(cka-2026-study) ✗ kc get po -A --watch | grep app
backend-app          backend-647b54c65b-k4cxk                              1/1     Running   0             55s
backend-app          backend-647b54c65b-rkmrs                              1/1     Running   0             55s
database-app         database-7ddb77779-mwmrz                              1/1     Running   0             45s
frontend-app         frontend-7668f7c4c8-ddppw                             1/1     Running   0             63s
frontend-app         frontend-7668f7c4c8-hpgx4                             1/1     Running   0             63s
^C
➜  Day-26 git:(cka-2026-study) ✗ kc get deploy -A | grep app
backend-app          backend                  2/2     2            2           72s
database-app         database                 1/1     1            1           62s
frontend-app         frontend                 2/2     2            2           80s
➜  Day-26 git:(cka-2026-study) ✗ kc get svc -A | grep app
backend-app    backend      ClusterIP   10.96.5.50      <none>        80/TCP                   83s
database-app   database     ClusterIP   10.96.94.44     <none>        3306/TCP                 73s
frontend-app   frontend     ClusterIP   10.96.162.226   <none>        80/TCP                   91s


---
Not worked with just svc but worked with FQDN (more details in day 10 notes.)
root@frontend-7668f7c4c8-ddppw:/# curl backend-svc:80
curl: (6) Could not resolve host: backend-svc
root@frontend-7668f7c4c8-ddppw:/# curl backend-svc.backend-app.svc.cluster.local:80
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, nginx is successfully installed and working.
Further configuration is required for the web server, reverse proxy,
API gateway, load balancer, content cache, or other features.</p>

<p>For online documentation and support please refer to
<a href="https://nginx.org/">nginx.org</a>.<br/>
To engage with the community please visit
<a href="https://community.nginx.org/">community.nginx.org</a>.<br/>
For enterprise grade support, professional services, additional
security features and capabilities please refer to
<a href="https://f5.com/nginx">f5.com/nginx</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
root@frontend-7668f7c4c8-ddppw:/#

----
Installed telnet and was able to reach db from frontend w/o network policies in place.

root@frontend-7668f7c4c8-ddppw:/# apt-get update && apt-get install telnet

root@frontend-7668f7c4c8-ddppw:/# telnet databse-svc:3306
Server lookup failure:  databse-svc:3306:telnet, Name or service not known

root@frontend-7668f7c4c8-ddppw:/# telnet database-svc.database-app.svc.cluster.local 3306
Trying 10.96.214.47...
Connected to database-svc.database-app.svc.cluster.local.
Escape character is '^]'.
J
26.7.0
jf]Hh7D�9(fRxC?fYcaching_sha2_password2#08S01Got timeout reading communication packetsConnection closed by foreign host.
root@frontend-7668f7c4c8-ddppw:/# telnet database-svc.database-app.svc.cluster.local 3306
Trying 10.96.214.47...
Connected to database-svc.database-app.svc.cluster.local.
Escape character is '^]'.
J
26.7.0
      !\=
         zB}�fVQ|@"(984!caching_sha2_password^]
telnet> quit
Connection closed.
root@frontend-7668f7c4c8-ddppw:/#

---
## Root cause + fix (backend → db was blocked too)

**Problem:** `network-policy.yaml` had two bugs:
1. `namespaceSelector: name: backend-app` — namespace had no `name` label (only `kubernetes.io/metadata.name`)
2. Separate `from` entries (podSelector OR namespaceSelector) — backend pods never matched → **deny all**

**Fix applied:** single `from` block with AND'd selectors + `kubectl label ns backend-app name=backend-app`

```bash
kubectl apply -f network-policy.yaml
# backend → db: succeeded
# frontend → db: timeout (expected)
```

Test **from backend**, not frontend, when verifying DB access.

---


root@frontend-7668f7c4c8-6gzw5:/# telnet backend-svc.backend-app.svc.cluster.local 80
Trying 10.96.148.44...
Connected to backend-svc.backend-app.svc.cluster.local.
Escape character is '^]'.
^]
telnet> quit
Connection closed.
root@frontend-7668f7c4c8-6gzw5:/# telnet database-svc.database-app.svc.cluster.local 3306
Trying 10.96.101.6...
^C
root@frontend-7668f7c4c8-6gzw5:/#

---
➜  Day-26 git:(cka-2026-study) ✗ kubectl-calico get networkpolicies
-n database-app
NAMESPACE      NAME                         TIER
database-app   allow-traffic-from-backend   default

----
