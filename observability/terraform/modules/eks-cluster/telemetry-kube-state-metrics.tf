# kube-state-metrics on workload — ADOT scrapes and remote_writes to obs Prometheus
# Required for default Grafana dashboards (Pod Compute, namespace dropdown, etc.)

resource "kubernetes_namespace_v1" "monitoring" {
  count = var.enable_infra_metrics_export ? 1 : 0

  metadata {
    name = var.monitoring_namespace
  }

  depends_on = [module.eks_addons]
}

resource "helm_release" "kube_state_metrics" {
  count = var.enable_infra_metrics_export ? 1 : 0

  name             = "kube-state-metrics"
  namespace        = var.monitoring_namespace
  create_namespace = false
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-state-metrics"
  version          = "5.30.1"
  timeout          = 600
  wait             = true

  values = [file("${path.module}/helm-values/kube-state-metrics-workload.yaml")]

  depends_on = [kubernetes_namespace_v1.monitoring]
}
