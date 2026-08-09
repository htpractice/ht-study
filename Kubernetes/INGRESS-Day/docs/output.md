# Ingress Day — lab output

Cluster: `ingress-lab` (kind) · Controller: **Traefik v3.7.9** (Helm) · App: Flask demo in `web-app`

---

## Summary

| Step | Result |
|------|--------|
| Helm install Traefik | **OK** — `traefik` ns, IngressClass `traefik` |
| Deploy app + Ingress | **OK** — Deployment, ClusterIP Service, Ingress applied |
| First curl via port-forward | **502 Bad Gateway** — Service `targetPort` mismatch |
| Fix `targetPort: 8080` | **OK** — app listens on 8080, not 80 |
| Final curl | **OK** — `Hello, World! from Flask` |

**Takeaway:** 502 from Ingress = controller is fine, backend unreachable. Check Pod ready → Service selector → **`targetPort` vs container port**.

---

## 1. Install Traefik (Helm)

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install traefik traefik/traefik \
  -n traefik --create-namespace \
  -f manifests/traefik-values.yaml
```

```
NAME: traefik
NAMESPACE: traefik
STATUS: deployed
REVISION: 1
NOTES: traefik with docker.io/traefik:v3.7.9 deployed successfully
```

```bash
kubectl wait -n traefik \
  --for=condition=ready pod \
  -l app.kubernetes.io/name=traefik \
  --timeout=120s
# pod/traefik-645c99bfd7-gdkhs condition met
```

---

## 2. Deploy app + Ingress

```bash
kubectl apply -f manifests/namespaces.yaml
kubectl apply -f manifests/web-deployment.yaml
kubectl apply -f manifests/web-svc.yaml
kubectl apply -f manifests/ingress.yaml
```

```
namespace/traefik configured
namespace/web-app unchanged
deployment.apps/web-deployment unchanged
service/web-svc unchanged
ingress.networking.k8s.io/ingress-service configured
```

---

## 3. Access via port-forward

```bash
kubectl port-forward -n traefik svc/traefik 8080:80
curl -H "Host: www.example.com" http://localhost:8080
```

Ingress rule uses host `www.example.com` — Host header required (or add `127.0.0.1 www.example.com` to `/etc/hosts`).

---

## 4. Troubleshooting — 502 Bad Gateway

**Symptom:**

```bash
curl -H "Host: www.example.com" http://localhost:8080
# Bad Gateway
```

**Pods and Service looked healthy:**

```bash
kubectl get all -n web-app
```

```
NAME                                 READY   STATUS    RESTARTS   AGE
pod/web-deployment-77fff59b7-rmlq4   1/1     Running   0          25m

NAME              TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/web-svc   ClusterIP   10.96.90.204   <none>        80/TCP    25m

NAME                             READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/web-deployment   1/1     1            1           25m
```

**Root cause:** Flask app in image listens on **8080** (`app.py`), but Service had `targetPort: 80`.

**Fix:**

```yaml
# manifests/web-svc.yaml
ports:
  - port: 80
    targetPort: 8080   # was 80
```

```bash
kubectl apply -f manifests/web-svc.yaml
curl -H "Host: www.example.com" http://localhost:8080
# Hello, World! from Flask
```

**Note:** ClusterIP (`10.96.x.x`) is not reachable from your laptop — only from inside the cluster. Use port-forward to Traefik or `kubectl exec` for testing.

---

## Traffic flow (verified)

```
curl (Host: www.example.com)
  → port-forward localhost:8080
  → traefik Service :80
  → Ingress rule (ingress-service)
  → web-svc:80 → Pod :8080
  → Flask response
```
