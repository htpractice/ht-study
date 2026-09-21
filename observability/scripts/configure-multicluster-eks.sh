#!/usr/bin/env bash
# Configure obs Prometheus to scrape workload EKS cluster (multicluster pattern).
# Run after retail-store workloads are up on workload-eks context.
set -euo pipefail

WORKLOAD_CTX="${WORKLOAD_CTX:-workload-eks}"
OBS_CTX="${OBS_CTX:-obs-eks}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

kubectl config use-context "${WORKLOAD_CTX}"
WORKLOAD_CLUSTER="${WORKLOAD_CLUSTER:-$(kubectl config current-context)}"

# Prometheus in workload (if kube-prometheus not installed, scrape pod metrics via nginx /metrics)
# For retail-store: services expose prometheus.io/scrape annotations — install a lightweight agent
# or use prometheus-node-exporter targets from workload nodes.

kubectl config use-context "${OBS_CTX}"

python3 <<'PY' > /tmp/prometheus-multicluster-values.yaml
import yaml

values = {
    "server": {
        "global": {"scrape_interval": "15s"},
        "persistentVolume": {"enabled": False},
    },
    "extraScrapeConfigs": """
- job_name: workload-kubernetes-pods
  kubernetes_sd_configs:
    - role: pod
  relabel_configs:
    - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
      action: keep
      regex: true
    - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
      action: replace
      target_label: __metrics_path__
      regex: (.+)
    - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
      action: replace
      regex: ([^:]+)(?::\\d+)?;(\\d+)
      replacement: $1:$2
      target_label: __address__
    - target_label: cluster
      replacement: workload
""",
    "alertmanager": {"enabled": False},
    "kube-state-metrics": {"enabled": True},
    "prometheus-node-exporter": {"enabled": True, "hostNetwork": True},
}
print(yaml.dump(values, default_flow_style=False, sort_keys=False))
PY

echo "NOTE: Cross-VPC pod SD requires obs Prometheus to reach workload API."
echo "For lab, prefer remote_write agent on workload — see docs/LAB-SPEC.md Phase 5."
echo ""
echo "Wrote /tmp/prometheus-multicluster-values.yaml — merge with manifests/prometheus-values.yaml manually."
