#!/usr/bin/env bash
# kube-state-metrics + node-exporter on dev for obs Grafana multi-cluster.
# obs Prometheus scrapes dev directly (9100 + 30301) — no Prometheus server on dev.
# Run on dev master:
#   bash Kubernetes/KubeADM-Day/scripts/install-dev-metrics.sh
#
# Prerequisite: dev SG allows TCP 9100 + 30301 from obs VPC (10.210.0.0/16).

set -euo pipefail

# Prefer ubuntu kubeconfig (kubeadm init); fall back to admin.conf when run as root.
if [[ -z "${KUBECONFIG:-}" ]]; then
  if [[ -f "${HOME}/.kube/config" ]]; then
    export KUBECONFIG="${HOME}/.kube/config"
  else
    export KUBECONFIG="/etc/kubernetes/admin.conf"
  fi
fi

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

if helm status prometheus -n observability >/dev/null 2>&1; then
  echo "==> Removing old full Prometheus release on dev (replaced by ksm + node-exporter only)"
  helm uninstall prometheus -n observability || true
fi

echo "==> kube-state-metrics (NodePort 30301, no ServiceMonitor)"
helm upgrade --install kube-state-metrics prometheus-community/kube-state-metrics \
  -n observability \
  --set prometheus.monitor.enabled=false \
  --set service.type=NodePort \
  --set service.nodePort=30301 \
  --set service.port=8080

echo "==> node-exporter (hostNetwork :9100, no ServiceMonitor)"
helm upgrade --install node-exporter prometheus-community/prometheus-node-exporter \
  -n observability \
  --set prometheus.monitor.enabled=false \
  --set prometheus.podMonitor.enabled=false \
  --set hostNetwork=true \
  --set 'tolerations[0].operator=Exists'

kubectl wait -n observability --for=condition=available deployment/kube-state-metrics --timeout=300s || true

MASTER_IP="$(hostname -I | awk '{print $1}')"
echo ""
echo "==> dev metrics ready (scraped by obs Prometheus)"
echo "    kube-state-metrics: ${MASTER_IP}:30301"
echo "    node-exporter:      <each-dev-node-ip>:9100"
echo ""
echo "On obs master:"
echo "  DEV_TARGET=${MASTER_IP}:30301 bash Kubernetes/KubeADM-Day/scripts/configure-obs-multicluster.sh"
echo ""
kubectl get pods -n observability
