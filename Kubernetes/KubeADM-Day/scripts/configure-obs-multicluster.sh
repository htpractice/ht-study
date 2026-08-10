#!/usr/bin/env bash
# Enable multi-cluster Grafana dashboards (15757/15760) on obs Prometheus.
# Run on obs master after install-dev-metrics.sh on dev:
#   DEV_TARGET=10.110.100.184:30300 bash ~/configure-obs-multicluster.sh

set -euo pipefail

REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/htpractice/ht-study/cka-2026-study}"
VALUES_URL="${REPO_RAW}/Kubernetes/KubeADM-Day/manifests/obs/prometheus-values.yaml"
DEV_TARGET="${DEV_TARGET:-}"

export KUBECONFIG="${KUBECONFIG:-/etc/kubernetes/admin.conf}"

if [[ -z "${DEV_TARGET}" ]]; then
  echo "ERROR: set DEV_TARGET to dev Prometheus NodePort, e.g. 10.110.100.184:30300" >&2
  exit 1
fi

if ! kubectl get nodes >/dev/null 2>&1; then
  echo "ERROR: kubectl cannot reach obs cluster." >&2
  exit 1
fi

echo "==> Testing federation endpoint ${DEV_TARGET}"
if ! curl -sf --max-time 10 "http://${DEV_TARGET}/-/ready" >/dev/null 2>&1; then
  echo "WARN: cannot reach http://${DEV_TARGET}/-/ready — check VPC peering, routes, dev SG (30300 from 10.210.0.0/16)" >&2
fi

echo "==> Upgrading obs Prometheus (cluster=obs + federate dev)"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update

curl -fsSL "${VALUES_URL}" | sed "s/DEV_PROMETHEUS_TARGET/${DEV_TARGET}/g" > /tmp/prometheus-obs-values.yaml

helm upgrade --install prometheus prometheus-community/prometheus \
  -n observability \
  -f /tmp/prometheus-obs-values.yaml

kubectl rollout status -n observability deployment/prometheus-server --timeout=300s || true

echo ""
echo "==> Verify in Grafana (Prometheus datasource):"
echo "    label_values(kube_node_info, cluster)  -> should show dev, obs"
echo ""
echo "Re-open dashboards 15757 / 15760 — Cluster dropdown should list dev and obs."
