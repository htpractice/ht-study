#!/usr/bin/env bash
# Telemetry is installed by Terraform (ADOT, Promtail, Loki, Jaeger, kube-prometheus-stack).
# This script verifies the observability pipeline after deploy-infra.sh.
set -euo pipefail

OBS_CTX="${OBS_CTX:-obs-eks}"
WORKLOAD_CTX="${WORKLOAD_CTX:-workload-eks}"

echo "==> Obs cluster pods"
kubectl --context "${OBS_CTX}" get pods -n monitoring
kubectl --context "${OBS_CTX}" get pods -n observability
kubectl --context "${OBS_CTX}" get pods -n opentelemetry-operator-system 2>/dev/null || true

echo "==> Workload ADOT + Promtail"
kubectl --context "${WORKLOAD_CTX}" get pods -n observability
kubectl --context "${WORKLOAD_CTX}" get pods -n opentelemetry-operator-system 2>/dev/null || true
kubectl --context "${WORKLOAD_CTX}" get applications -n argocd 2>/dev/null || true

echo ""
echo "Port-forward Grafana:"
echo "  kubectl --context ${OBS_CTX} port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo "Prometheus targets:"
echo "  kubectl --context ${OBS_CTX} port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
