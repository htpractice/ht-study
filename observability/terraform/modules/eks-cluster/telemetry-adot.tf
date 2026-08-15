# ADOT EKS add-on (operator) + OpenTelemetryCollector CR

resource "time_sleep" "wait_for_adot_deps" {
  count = var.enable_adot ? 1 : 0

  create_duration = "60s"
  depends_on      = [module.eks_addons]
}

resource "kubectl_manifest" "adot_collector" {
  count = var.enable_adot ? 1 : 0

  yaml_body = templatefile("${path.module}/templates/adot-collector.yaml.tpl", {
    cluster_label               = local.telemetry_cluster_label
    prometheus_remote_write_url = local.prometheus_remote_write_url
    jaeger_otlp_endpoint        = local.jaeger_otlp_endpoint
  })

  depends_on = [
    time_sleep.wait_for_adot_deps,
    kubernetes_service_account_v1.adot_collector,
    kubernetes_cluster_role_binding_v1.adot_collector,
  ]
}
