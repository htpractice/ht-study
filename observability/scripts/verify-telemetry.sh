#!/usr/bin/env bash
# Telemetry is installed by Terraform (ADOT, Promtail, Loki, Jaeger, kube-prometheus-stack).
# This script verifies the observability pipeline after deploy-infra.sh.
set -euo pipefail

OBS_CTX="${OBS_CTX:-obs-eks}"
WORKLOAD_CTX="${WORKLOAD_CTX:-workload-eks}"

echo "==> Obs cluster pods"
kubectl --context "${OBS_CTX}" get pods -n monitoring
kubectl --context "${OBS_CTX}" get pods -n observability
kubectl --context "${OBS_CTX}" get pods -n observability -l app=jaeger
kubectl --context "${OBS_CTX}" get endpoints -n observability jaeger 2>/dev/null || true
kubectl --context "${OBS_CTX}" get pods -n opentelemetry-operator-system 2>/dev/null || true

echo "==> Workload ADOT + Promtail + kube-state-metrics"
kubectl --context "${WORKLOAD_CTX}" get pods -n observability
kubectl --context "${WORKLOAD_CTX}" get pods -n monitoring 2>/dev/null || true
kubectl --context "${WORKLOAD_CTX}" get pods -n opentelemetry-operator-system 2>/dev/null || true
kubectl --context "${WORKLOAD_CTX}" get applications -n argocd 2>/dev/null || true

echo "==> Infra metrics in obs Prometheus (kube-state + cAdvisor from workload)"
if kubectl --context "${OBS_CTX}" get pod -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 &>/dev/null; then
  kubectl --context "${OBS_CTX}" exec -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 -c prometheus -- \
    wget -qO- 'http://localhost:9090/api/v1/query?query=count(kube_pod_info{namespace="retail-store"})' 2>/dev/null || true
  echo
  kubectl --context "${OBS_CTX}" exec -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 -c prometheus -- \
    wget -qO- 'http://localhost:9090/api/v1/query?query=count(container_cpu_usage_seconds_total{namespace="retail-store"})' 2>/dev/null || true
  echo
fi

echo ""
echo "Port-forward Grafana:"
echo "  kubectl --context ${OBS_CTX} port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo "Prometheus UI:"
echo "  kubectl --context ${OBS_CTX} port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
echo ""
echo "Grafana dashboards: Kubernetes / Compute Resources / Pod — namespace dropdown should include retail-store"
