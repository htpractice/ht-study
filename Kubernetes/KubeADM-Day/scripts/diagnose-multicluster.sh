#!/usr/bin/env bash
# Quick checks for multi-cluster Grafana (dashboards 15757/15760).
# Run on obs-master.

set -euo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  if [[ -f "${HOME}/.kube/config" ]]; then
    export KUBECONFIG="${HOME}/.kube/config"
  else
    export KUBECONFIG="/etc/kubernetes/admin.conf"
  fi
fi

DEV_KUBECONFIG="${DEV_KUBECONFIG:-${HOME}/.kube/dev-config}"
DEV_TARGET="${DEV_TARGET:-}"

echo "==> [1] obs Prometheus config — cluster external_label + federate-dev job"
kubectl get cm -n observability -l app.kubernetes.io/name=prometheus -o name 2>/dev/null | head -1 | xargs -r kubectl get -n observability -o yaml | grep -E "cluster:|federate-dev|DEV_PROMETHEUS" || echo "WARN: no prometheus CM or missing cluster/federation"

echo ""
echo "==> [2] obs Prometheus targets"
kubectl port-forward -n observability svc/prometheus-server 9090:80 >/tmp/pf-prom.log 2>&1 &
PF_PID=$!
sleep 2
curl -sf "http://127.0.0.1:9090/api/v1/targets" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for t in d.get('data',{}).get('activeTargets',[]):
    lbl=t.get('labels',{})
    print(lbl.get('job','?'), lbl.get('cluster','-'), t.get('health'), t.get('scrapeUrl',''), t.get('lastError','')[:80])
" 2>/dev/null || echo "WARN: cannot query prometheus targets"
echo ""
echo "    cluster label values:"
curl -sf "http://127.0.0.1:9090/api/v1/label/cluster/values" 2>/dev/null | python3 -m json.tool || echo "WARN: no cluster label yet"
echo ""
echo "    kube_node_info count by cluster:"
curl -sf "http://127.0.0.1:9090/api/v1/query?query=count%20by%20(cluster)%20(kube_node_info)" 2>/dev/null | python3 -m json.tool || true
kill "${PF_PID}" 2>/dev/null || true

echo ""
echo "==> [3] dev cluster nodes (from dev-config)"
if [[ -f "${DEV_KUBECONFIG}" ]]; then
  kubectl --kubeconfig "${DEV_KUBECONFIG}" get nodes -o wide
else
  echo "WARN: ${DEV_KUBECONFIG} not found on obs-master"
fi

echo ""
echo "==> [4] TCP from obs-master to dev Prometheus NodePort"
if [[ -n "${DEV_TARGET}" ]]; then
  nc -vz -w 3 "${DEV_TARGET%%:*}" "${DEV_TARGET##*:}" || echo "FAIL: cannot reach ${DEV_TARGET} — add dev SG TCP ${DEV_TARGET##*:} from 10.210.0.0/16"
  curl -sf --max-time 5 "http://${DEV_TARGET}/metrics" | head -1 && echo "OK: dev kube-state-metrics reachable at http://${DEV_TARGET}/metrics" || echo "FAIL: cannot scrape http://${DEV_TARGET}/metrics"
else
  echo "Set DEV_TARGET=10.110.x.x:30300 to test dev Prometheus reachability"
fi
