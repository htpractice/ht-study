#!/usr/bin/env bash
# Add Loki + Jaeger on obs EKS cluster.
# Prometheus/Grafana already installed via Terraform (kube-prometheus-stack).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KUBECTX="${KUBECTX:-obs-eks}"

if ! kubectl config get-contexts "${KUBECTX}" >/dev/null 2>&1; then
  echo "ERROR: context '${KUBECTX}' not found. Run deploy-infra.sh first." >&2
  exit 1
fi

kubectl config use-context "${KUBECTX}"

echo "==> observability namespace (for Loki/Jaeger — Prometheus is in monitoring ns)"
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

echo "==> Loki stack"
helm upgrade --install loki grafana/loki-stack \
  -n observability \
  -f "${SCRIPT_DIR}/manifests/loki-stack-values.yaml"

echo "==> Jaeger"
kubectl apply -f "${SCRIPT_DIR}/manifests/jaeger.yaml"

OTEL="${SCRIPT_DIR}/../Kubernetes/Logs&Monitoring-Day/manifests/otel-collector.yaml"
if [[ -f "${OTEL}" ]]; then
  kubectl apply -f "${OTEL}"
fi

echo ""
echo "Prometheus/Grafana: kubectl --context ${KUBECTX} get pods -n monitoring"
echo "Grafana password: kubectl --context ${KUBECTX} get secret -n monitoring prometheus-grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo"
echo "Port-forward: kubectl --context ${KUBECTX} port-forward -n monitoring svc/prometheus-grafana 3000:80"
