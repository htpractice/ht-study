#!/usr/bin/env bash
# Promtail on dev — ships order-api stdout logs to obs Loki over peered VPC.
# Run on dev master after obs Loki NodePort is live:
#   LOKI_TARGET=10.210.100.57:30100 bash install-dev-promtail.sh
#
# Prerequisite: obs SG allows TCP 30100 from dev VPC (10.110.0.0/16).

set -euo pipefail

LOKI_TARGET="${LOKI_TARGET:-}"

if [[ -z "${KUBECONFIG:-}" ]]; then
  if [[ -f "${HOME}/.kube/config" ]]; then
    export KUBECONFIG="${HOME}/.kube/config"
  else
    export KUBECONFIG="/etc/kubernetes/admin.conf"
  fi
fi

if [[ -z "${LOKI_TARGET}" ]]; then
  echo "ERROR: set LOKI_TARGET to obs Loki NodePort, e.g. 10.210.100.57:30100" >&2
  exit 1
fi

if ! kubectl get nodes >/dev/null 2>&1; then
  echo "ERROR: kubectl cannot reach dev cluster." >&2
  exit 1
fi

echo "==> Connectivity dev → obs Loki"
nc -vz -w 3 "${LOKI_TARGET%%:*}" "${LOKI_TARGET##*:}" </dev/null 2>&1 | tail -1 \
  || echo "WARN: cannot reach ${LOKI_TARGET} — add obs SG TCP ${LOKI_TARGET##*:} from 10.110.0.0/16"

echo "==> Helm"
if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update

echo "==> Namespace observability"
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -

echo "==> Promtail (DaemonSet → obs Loki, cluster=dev label)"
helm upgrade --install promtail grafana/promtail \
  -n observability \
  --set "config.clients[0].url=http://${LOKI_TARGET}/loki/api/v1/push" \
  --set "config.clients[0].external_labels.cluster=dev" \
  --set 'tolerations[0].operator=Exists'

kubectl rollout status -n observability daemonset/promtail --timeout=300s || true

echo ""
echo "==> dev promtail ready"
echo "    Loki push target: http://${LOKI_TARGET}/loki/api/v1/push"
echo ""
echo "Generate traffic, then in Grafana Explore (Loki):"
echo '  {namespace="order-api", cluster="dev"}'
echo ""
kubectl get pods -n observability -l app.kubernetes.io/name=promtail
