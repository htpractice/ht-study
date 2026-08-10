#!/usr/bin/env bash
# Enable multi-cluster Grafana dashboards (15757/15760) on obs Prometheus.
# Run on obs master after install-dev-metrics.sh on dev:
#   DEV_TARGET=10.110.100.184:30301 bash configure-obs-multicluster.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_TARGET="${DEV_TARGET:-}"
DEV_KUBECONFIG="${DEV_KUBECONFIG:-${HOME}/.kube/dev-config}"

if [[ -z "${KUBECONFIG:-}" ]]; then
  if [[ -f "${HOME}/.kube/config" ]]; then
    export KUBECONFIG="${HOME}/.kube/config"
  else
    export KUBECONFIG="/etc/kubernetes/admin.conf"
  fi
fi

if [[ -z "${DEV_TARGET}" ]]; then
  echo "ERROR: set DEV_TARGET to dev KSM NodePort, e.g. 10.110.100.184:30301" >&2
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

if ! python3 -c "import yaml" 2>/dev/null; then
  echo "==> Installing python3-yaml (required to render Helm values)"
  sudo apt-get update -qq && sudo apt-get install -y -qq python3-yaml
fi

DEV_MASTER_IP="${DEV_TARGET%%:*}"
KSM_NODEPORT="${DEV_TARGET##*:}"
mapfile -t DEV_NODE_IPS < <(kubectl --kubeconfig "${DEV_KUBECONFIG}" get nodes -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}')

echo "==> Connectivity obs → dev"
for ip in "${DEV_NODE_IPS[@]}"; do
  nc -vz -w 3 "${ip}" 9100 </dev/null 2>&1 | tail -1 || echo "WARN: ${ip}:9100 blocked"
done
nc -vz -w 3 "${DEV_MASTER_IP}" "${KSM_NODEPORT}" </dev/null 2>&1 | tail -1 || echo "WARN: ${DEV_TARGET} blocked"

DEV_IPS_FILE="/tmp/dev-node-ips.txt"
printf '%s\n' "${DEV_NODE_IPS[@]}" > "${DEV_IPS_FILE}"

python3 <<PY
import yaml
from pathlib import Path

dev_ips = [ip.strip() for ip in Path("${DEV_IPS_FILE}").read_text().splitlines() if ip.strip()]
dev_targets = [f"{ip}:9100" for ip in dev_ips]

values = {
    "server": {
        "global": {"scrape_interval": "15s"},
        "persistentVolume": {"enabled": False},
    },
    "scrapeConfigs": {
        "obs-kube-state-metrics": {
            "enabled": True,
            "static_configs": [
                {"targets": ["prometheus-kube-state-metrics.observability.svc.cluster.local:8080"]}
            ],
            "metric_relabel_configs": [{"target_label": "cluster", "replacement": "obs"}],
        },
        "obs-node-exporter": {
            "enabled": True,
            "kubernetes_sd_configs": [{"role": "node"}],
            "relabel_configs": [
                {"source_labels": ["__address__"], "regex": "(.*):10250", "replacement": r"\${1}:9100", "target_label": "__address__"},
                {"target_label": "cluster", "replacement": "obs"},
                {"target_label": "job", "replacement": "obs-node-exporter"},
            ],
            "metric_relabel_configs": [{"target_label": "cluster", "replacement": "obs"}],
        },
        "dev-node-exporter": {
            "enabled": True,
            "static_configs": [{"targets": dev_targets}],
            "relabel_configs": [
                {"target_label": "cluster", "replacement": "dev"},
                {"target_label": "job", "replacement": "dev-node-exporter"},
            ],
            "metric_relabel_configs": [{"target_label": "cluster", "replacement": "dev"}],
        },
        "dev-kube-state-metrics": {
            "enabled": True,
            "static_configs": [{"targets": [f"${DEV_MASTER_IP}:${KSM_NODEPORT}"]}],
            "relabel_configs": [
                {"target_label": "cluster", "replacement": "dev"},
                {"target_label": "job", "replacement": "kube-state-metrics"},
            ],
            "metric_relabel_configs": [{"target_label": "cluster", "replacement": "dev"}],
        },
    },
    "alertmanager": {"enabled": False},
    "kube-state-metrics": {"enabled": True, "prometheus": {"monitor": {"enabled": False}}},
    "prometheus-node-exporter": {
        "enabled": True,
        "hostNetwork": True,
        "tolerations": [{"operator": "Exists"}],
        "prometheus": {"monitor": {"enabled": False}},
    },
    "prometheus-pushgateway": {"enabled": False},
}

Path("/tmp/prometheus-obs-values.yaml").write_text(yaml.dump(values, default_flow_style=False, sort_keys=False))
print("Wrote /tmp/prometheus-obs-values.yaml")
PY

echo "==> Upgrading obs Prometheus (scrapeConfigs map — chart v29)"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update
helm upgrade --install prometheus prometheus-community/prometheus \
  -n observability \
  --set kube-state-metrics.prometheus.monitor.enabled=false \
  --set prometheus-node-exporter.prometheus.monitor.enabled=false \
  --set prometheus-node-exporter.prometheus.podMonitor.enabled=false \
  -f /tmp/prometheus-obs-values.yaml

kubectl rollout status -n observability deployment/prometheus-server --timeout=300s || true
sleep 25

echo ""
echo "==> Verify dev targets"
if curl -sf http://127.0.0.1:9090/api/v1/targets >/tmp/targets.json 2>/dev/null; then
  python3 -c "
import json
d=json.load(open('/tmp/targets.json'))
dev=[t for t in d['data']['activeTargets'] if 'dev' in t['labels'].get('job','')]
print(f'dev targets: {len(dev)}')
for t in dev:
    print(t['labels']['job'], t['health'], t['scrapeUrl'])
clusters=__import__('urllib.request').urlopen('http://127.0.0.1:9090/api/v1/label/cluster/values').read()
print('cluster labels:', json.loads(clusters).get('data',[]))
"
else
  echo "Start port-forward: kubectl port-forward -n observability svc/prometheus-server 9090:80"
fi
