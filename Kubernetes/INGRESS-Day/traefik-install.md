# Traefik Ingress Lab (2026)

Community **ingress-nginx** retired in March 2026. The **Ingress API** is still valid for CKA — only the controller install changed. This folder uses **Traefik** for hands-on practice.

## What you deploy

| Component | Namespace | File |
|-----------|-----------|------|
| Traefik controller | `traefik` | Helm + `traefik-values.yaml` (or `traefik-manifest.yaml` without Helm) |
| Web app | `web-app` | `web-deployment.yaml`, `web-svc.yaml` |
| Ingress rules | `web-app` | `ingress.yaml` |

Traffic flow: **Client → Traefik → web-svc (ClusterIP) → Pod**

## Prerequisites

- `kubectl`
- `kind` (or minikube)
- `helm` v3+ (recommended) — or use `traefik-manifest.yaml` without Helm

## Quick start (Helm — recommended)

```bash
cd ht-study/Kubernetes/INGRESS-Day

# 1. Create cluster
kind create cluster --name ingress-lab

# 2. Install Traefik
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install traefik traefik/traefik \
  -n traefik --create-namespace \
  -f traefik-values.yaml

# 3. Wait for Traefik
kubectl wait -n traefik \
  --for=condition=ready pod \
  -l app.kubernetes.io/name=traefik \
  --timeout=120s

# 4. Deploy app + Ingress
kubectl apply -f namespaces.yaml
kubectl apply -f web-deployment.yaml
kubectl apply -f web-svc.yaml
kubectl apply -f ingress.yaml

# 5. Port-forward Traefik (separate terminal)
kubectl port-forward -n traefik svc/traefik 8080:80

# 6. Test
curl -H "Host: www.example.com" http://localhost:8080
```

Expected output: `Hello, World! from Flask` (or similar from your image).

Optional `/etc/hosts` entry so you can skip `-H`:

```text
127.0.0.1 www.example.com
```

Then: `curl http://www.example.com:8080`

## Option B: kubectl only (no Helm)

```bash
kind create cluster --name ingress-lab
kubectl apply -f traefik-manifest.yaml
kubectl wait -n traefik \
  --for=condition=ready pod \
  -l app.kubernetes.io/name=traefik \
  --timeout=120s

kubectl apply -f namespaces.yaml
kubectl apply -f web-deployment.yaml
kubectl apply -f web-svc.yaml
kubectl apply -f ingress.yaml

kubectl port-forward -n traefik svc/traefik 8080:80
curl -H "Host: www.example.com" http://localhost:8080
```

## Option C: kind with host port 80

Use `kind-ingress-config.yaml` so Traefik binds to port 80 on the kind node.

```bash
kind delete cluster --name ingress-lab 2>/dev/null || true
kind create cluster --name ingress-lab --config kind-ingress-config.yaml

helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install traefik traefik/traefik \
  -n traefik --create-namespace \
  -f traefik-values-kind-hostport.yaml

kubectl apply -f namespaces.yaml
kubectl apply -f web-deployment.yaml
kubectl apply -f web-svc.yaml
kubectl apply -f ingress.yaml

# Map host to kind node (Docker Desktop / Linux)
# Add to /etc/hosts: 127.0.0.1 www.example.com
curl http://www.example.com
```

## Verify Ingress is wired

```bash
# IngressClass exists
kubectl get ingressclass

# Traefik picked up the Ingress
kubectl describe ingress ingress-service -n web-app

# Traefik logs
kubectl logs -n traefik -l app.kubernetes.io/name=traefik --tail=50
```

## Troubleshooting

| Symptom | Check |
|---------|-------|
| `404` from Traefik | `ingressClassName: traefik` matches Traefik's class; Service name/port correct |
| `502` / bad gateway | Pods ready? `kubectl get pods -n web-app`; Service selector matches Pod labels |
| Connection refused on :8080 | Port-forward running? Traefik pod ready? |
| Wrong host | Ingress rule uses `www.example.com` — send that Host header or add `/etc/hosts` |

## CKA note

The exam tests **Ingress resource YAML** (rules, paths, `pathType`, TLS, `ingressClassName`). You usually do not install a controller from scratch. Focus on writing correct `Ingress` manifests; Traefik here is for local labs only.

## Cleanup

```bash
kind delete cluster --name ingress-lab
```

## Legacy ingress-nginx (local only, not recommended)

Archived manifests still work for old tutorials but receive no security updates:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.0/deploy/static/provider/kind/deploy.yaml
```

Use `ingressClassName: nginx` and NGINX-specific annotations only if following an older course video.
