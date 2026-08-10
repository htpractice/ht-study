#!/usr/bin/env bash
# Enable multi-cluster Grafana dashboards (15757/15760) on obs Prometheus.
# Run on obs master after install-dev-metrics.sh on dev:
#   DEV_TARGET=10.110.100.184:30300 bash configure-obs-multicluster.sh
#
# Requires dev SG: TCP 9100, 30300, 30301 from 10.210.0.0/16 (obs VPC).

set -euo pipefail

REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/htpractice/ht-study/cka-2026-study}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DEV_TARGET="${DEV_TARGET:-}"
DEV_KUBECONFIG="${DEV_KUBECONFIG:-${HOME}/.kube/dev-config}"
KSM_NODEPORT="${KSM_NODEPORT:-30301}"

if [[ -z "${KUBECONFIG:-}" ]]; then
  if [[ -f "${HOME}/.kube/config" ]]; then
    export KUBECONFIG="${HOME}/.kube/config"
  else
    export KUBECONFIG="/etc/kubernetes/admin.conf"
  fi
fi

if [[ -z "${DEV_TARGET}" ]]; then
  echo "ERROR: set DEV_TARGET to dev Prometheus NodePort, e.g. 10.110.100.184:30300" >&2
  exit 1
fi

if ! kubectl get nodes >/dev/null 2>&1; then
  echo "ERROR: kubectl cannot reach obs cluster." >&2
  exit 1
fi

if ! command -v helm >/dev/null 2>&1; then
  echo "ERROR: helm not found on obs master." >&2
  exit 1
fi

if [[ ! -f "${DEV_KUBECONFIG}" ]]; then
  echo "ERROR: ${DEV_KUBECONFIG} missing — copy dev kubeconfig to obs-master" >&2
  exit 1
fi

DEV_MASTER_IP="${DEV_TARGET%%:*}"
mapfile -t DEV_NODE_IPS < <(kubectl --kubeconfig "${DEV_KUBECONFIG}" get nodes -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}')

echo "==> Connectivity obs → dev"
for ip in "${DEV_NODE_IPS[@]}"; do
  nc -vz -w 3 "${ip}" 9100 </dev/null 2>&1 | tail -1 || echo "WARN: ${ip}:9100 blocked — add dev SG TCP 9100 from 10.210.0.0/16"
done
nc -vz -w 3 "${DEV_MASTER_IP}" "${DEV_TARGET##*:}" </dev/null 2>&1 | tail -1 || echo "WARN: ${DEV_TARGET} blocked — add dev SG TCP ${DEV_TARGET##*:} from 10.210.0.0/16"
nc -vz -w 3 "${DEV_MASTER_IP}" "${KSM_NODEPORT}" </dev/null 2>&1 | tail -1 || echo "WARN: ${DEV_MASTER_IP}:${KSM_NODEPORT} blocked — git pull + re-run install-dev-metrics.sh on dev"

BASE_VALUES="${REPO_ROOT}/Kubernetes/KubeADM-Day/manifests/obs/prometheus-values.yaml"
if [[ ! -f "${BASE_VALUES}" ]]; then
  curl -fsSL "${REPO_RAW}/Kubernetes/KubeADM-Day/manifests/obs/prometheus-values.yaml" -o /tmp/prometheus-obs-base.yaml
  BASE_VALUES="/tmp/prometheus-obs-base.yaml"
fi

NODE_TARGETS_FILE="/tmp/dev-node-targets.yaml"
: > "${NODE_TARGETS_FILE}"
for ip in "${DEV_NODE_IPS[@]}"; do
  printf '            - "%s:9100"\n' "${ip}" >> "${NODE_TARGETS_FILE}"
done

sed "s/DEV_PROMETHEUS_TARGET/${DEV_TARGET}/g" "${BASE_VALUES}" > /tmp/prometheus-obs-values.yaml

cat > /tmp/dev-extra-jobs.yaml <<EOF
    - job_name: dev-node-exporter
      static_configs:
        - targets:
$(cat "${NODE_TARGETS_FILE}")
      relabel_configs:
        - target_label: cluster
          replacement: dev
        - target_label: job
          replacement: node-exporter
      metric_relabel_configs:
        - target_label: cluster
          replacement: dev
    - job_name: dev-kube-state-metrics
      static_configs:
        - targets:
            - "${DEV_MASTER_IP}:${KSM_NODEPORT}"
      relabel_configs:
        - target_label: cluster
          replacement: dev
        - target_label: job
          replacement: kube-state-metrics
      metric_relabel_configs:
        - target_label: cluster
          replacement: dev
EOF

awk '
/^alertmanager:/ {
  while ((getline line < "/tmp/dev-extra-jobs.yaml") > 0) print line
}
{ print }
' /tmp/prometheus-obs-values.yaml > /tmp/prometheus-obs-final.yaml
mv /tmp/prometheus-obs-final.yaml /tmp/prometheus-obs-values.yaml

echo "==> Upgrading obs Prometheus"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update
helm upgrade --install prometheus prometheus-community/prometheus \
  -n observability \
  -f /tmp/prometheus-obs-values.yaml

kubectl rollout status -n observability deployment/prometheus-server --timeout=300s || true
sleep 20

echo ""
echo "==> Verify"
bash "${SCRIPT_DIR}/diagnose-multicluster.sh" || true

echo ""
echo "Grafana: label_values(kube_node_info, cluster) should list dev + obs"
