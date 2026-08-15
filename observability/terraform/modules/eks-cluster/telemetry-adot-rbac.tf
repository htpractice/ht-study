# SA + RBAC for ADOT collector kubernetes_sd scraping (required before OpenTelemetryCollector CR)

resource "kubernetes_service_account_v1" "adot_collector" {
  count = var.enable_adot ? 1 : 0

  metadata {
    name      = "adot-collector"
    namespace = var.adot_namespace
  }

  depends_on = [time_sleep.wait_for_adot_deps]
}

resource "kubernetes_cluster_role_v1" "adot_collector" {
  count = var.enable_adot ? 1 : 0

  metadata {
    name = "adot-collector"
  }

  rule {
    api_groups = [""]
    resources  = ["nodes", "nodes/proxy", "nodes/metrics", "services", "endpoints", "pods", "namespaces", "configmaps"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    non_resource_urls = ["/metrics"]
    verbs             = ["get"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "adot_collector" {
  count = var.enable_adot ? 1 : 0

  metadata {
    name = "adot-collector"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.adot_collector[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.adot_collector[0].metadata[0].name
    namespace = var.adot_namespace
  }
}
