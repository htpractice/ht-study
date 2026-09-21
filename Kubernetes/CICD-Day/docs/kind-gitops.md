# kind GitOps — same Helm + Argo, zero AWS cost

Use after (or instead of) [aws-e2e-afternoon.md](aws-e2e-afternoon.md).

---

## Prerequisites

- `kind-cka-cluster01` running
- Docker Hub image `hthaware2508/order-api-lab:v1` exists

---

## Phase 1 — Argo CD on kind

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl wait -n argocd --for=condition=available deployment/argocd-server --timeout=300s
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

---

## Phase 2 — Helm values for kind

Edit `helm/order-api/values.yaml`:

```yaml
image:
  repository: hthaware2508/order-api-lab
  tag: v1
service:
  type: ClusterIP
env:
  deploymentEnv: kind-lab
```

Push to `cka-2026-study`.

---

## Phase 3 — Argo Application

```bash
kubectl apply -f argocd/application-order-api.yaml
kubectl get applications -n argocd
kubectl get pods -n order-api
```

Port-forward to test:

```bash
kubectl port-forward -n order-api svc/order-api 8080:80
curl localhost:8080/health
```

---

## Phase 4 — GitHub Actions (optional on kind)

Actions still builds/pushes to **ECR** if AWS secrets set. For kind-only without AWS:

- Manually `docker build/push` to Docker Hub
- Edit `values.yaml` tag locally, push Git, Argo syncs

Or add a second workflow job for Docker Hub (future).

---

## Teardown

```bash
kubectl delete application order-api -n argocd
kubectl delete ns order-api argocd
```

Cluster stays for other labs.
