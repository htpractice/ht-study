# Promtail DaemonSet — tails node container logs, pushes to central Loki

resource "helm_release" "promtail" {
  count = var.enable_promtail ? 1 : 0

  name             = "promtail"
  namespace        = var.observability_namespace
  create_namespace = false
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "promtail"
  version          = "6.16.6"

  values = [
    templatefile("${path.module}/templates/promtail-values.yaml.tpl", {
      loki_push_url = local.loki_push_url
      cluster_label = local.telemetry_cluster_label
    })
  ]

  depends_on = [
    module.eks_addons,
    kubernetes_namespace_v1.observability,
  ]
}
