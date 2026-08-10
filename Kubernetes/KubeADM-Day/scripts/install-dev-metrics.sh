#!/usr/bin/env bash
# Prometheus + kube-state-metrics + node-exporter on dev for obs Grafana multi-cluster.
# Run on dev master after nodes Ready:
#   bash ~/install-dev-metrics.sh
#
# Prerequisite: dev worker/CP SG allows TCP 30300 from obs VPC (10.210.0.0/16).

set -euo pipefail

REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/htpractice/ht-study/cka-2026-study}"
VALUES_URL="${REPO_RAW}/Kubernetes/KubeADM-Day/manifests/dev/prometheus-values.yaml"

export KUBECONFIG="${KUBECONFIG:-/etc/kubernetes/admin.conf}"

if ! kubectl get nodes >/dev/null 2>&1; then
  echo "ERROR: kubectl cannot reach dev cluster." >&2
  exit 1
fi

echo "==> Helm"
if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update

echo "==> Namespace observability"
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -

echo "==> Prometheus (cluster label=dev, NodePort 30300 for federation)"
helm upgrade --install prometheus prometheus-community/prometheus \
  -n observability \
  -f <(curl -fsSL "${VALUES_URL}")

kubectl wait -n observability --for=condition=available deployment/prometheus-server --timeout=600s || true

MASTER_IP="$(hostname -I | awk '{print $1}')"
echo ""
echo "==> dev metrics ready"
echo "    Federation target for obs: ${MASTER_IP}:30300"
echo ""
echo "On obs master, run:"
echo "  DEV_TARGET=${MASTER_IP}:30300 bash ~/configure-obs-multicluster.sh"
echo ""
kubectl get pods -n observability
