#!/usr/bin/env bash
# Install observability platform on obs kubeadm cluster.
# Run on obs master (ubuntu) after all nodes are Ready:
#   bash ~/install-obs-stack.sh
#
# Stack: Prometheus, Grafana, Loki, Promtail, Jaeger, OTel Collector, Argo CD

set -euo pipefail

REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/htpractice/ht-study/cka-2026-study}"
MANIFEST_BASE="${REPO_RAW}/Kubernetes"
OBS_VALUES="${MANIFEST_BASE}/KubeADM-Day/manifests/obs"
LOGS_MANIFESTS="${MANIFEST_BASE}/Logs%26Monitoring-Day/manifests"

export KUBECONFIG="${KUBECONFIG:-/etc/kubernetes/admin.conf}"

if ! kubectl get nodes >/dev/null 2>&1; then
  echo "ERROR: kubectl cannot reach cluster. Run on obs master with admin kubeconfig." >&2
  exit 1
fi

echo "==> [1/7] Helm"
if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update

echo "==> [2/7] Namespace observability"
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -

echo "==> [3/8] Prometheus"
helm upgrade --install prometheus prometheus-community/prometheus \
  -n observability \
  -f <(curl -fsSL "${OBS_VALUES}/prometheus-values.yaml")

echo "==> [4/8] Grafana (separate chart — prometheus chart no longer bundles it)"
helm upgrade --install grafana grafana/grafana \
  -n observability \
  -f <(curl -fsSL "${OBS_VALUES}/grafana-values.yaml")

echo "==> [5/8] Loki + Promtail"
helm upgrade --install loki grafana/loki-stack \
  -n observability \
  -f <(curl -fsSL "${OBS_VALUES}/loki-stack-values.yaml")

echo "==> [6/8] Jaeger + OpenTelemetry Collector"
curl -fsSL "${LOGS_MANIFESTS}/jaeger.yaml" | kubectl apply -f -
curl -fsSL "${LOGS_MANIFESTS}/otel-collector.yaml" | kubectl apply -f -

echo "==> [7/8] Argo CD"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait -n argocd --for=condition=available deployment/argocd-server --timeout=600s

echo "==> [8/8] Wait for core pods"
kubectl wait -n observability --for=condition=available deployment/prometheus-server --timeout=600s || true
kubectl wait -n observability --for=condition=available deployment/grafana --timeout=600s || true
kubectl wait -n observability --for=condition=available deployment/jaeger --timeout=300s || true
kubectl wait -n observability --for=condition=available deployment/otel-collector --timeout=300s || true

echo ""
echo "==> obs stack installed"
echo ""
kubectl get pods -n observability
kubectl get pods -n argocd
echo ""
echo "Grafana:  admin / cka-lab"
echo "  kubectl port-forward -n observability svc/grafana 3000:80"
echo ""
echo "Jaeger UI:"
echo "  kubectl port-forward -n observability svc/jaeger 16686:16686"
echo ""
echo "Argo CD UI:"
echo "  kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo "  user: admin  pass:"
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "(wait for secret)"
echo ""
