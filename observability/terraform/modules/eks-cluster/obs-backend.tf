# Loki + Jaeger central backends (obs cluster only)

resource "kubernetes_namespace_v1" "observability" {
  count = (var.enable_obs_backend || var.enable_promtail) ? 1 : 0

  metadata {
    name = var.observability_namespace
  }

  depends_on = [module.eks_addons]
}

resource "helm_release" "loki" {
  count = var.enable_obs_backend ? 1 : 0

  name             = "loki"
  namespace        = var.observability_namespace
  create_namespace = false
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki-stack"
  version          = "2.10.2"
  timeout          = 600
  wait             = true

  values = [file("${path.module}/helm-values/loki-stack-obs.yaml")]

  depends_on = [kubernetes_namespace_v1.observability]
}

# kubectl_manifest applies one resource per block; multi-doc jaeger.yaml only created the Service.
resource "kubectl_manifest" "jaeger_service" {
  count = var.enable_obs_backend ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: v1
    kind: Service
    metadata:
      name: jaeger
      namespace: ${var.observability_namespace}
      labels:
        app: jaeger
    spec:
      selector:
        app: jaeger
      ports:
        - name: ui
          port: 16686
          targetPort: 16686
        - name: otlp-grpc
          port: 4317
          targetPort: 4317
        - name: otlp-http
          port: 4318
          targetPort: 4318
  YAML

  depends_on = [kubernetes_namespace_v1.observability]
}

resource "kubectl_manifest" "jaeger_deployment" {
  count = var.enable_obs_backend ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: jaeger
      namespace: ${var.observability_namespace}
      labels:
        app: jaeger
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: jaeger
      template:
        metadata:
          labels:
            app: jaeger
        spec:
          containers:
            - name: jaeger
              image: jaegertracing/all-in-one:1.57
              env:
                - name: COLLECTOR_OTLP_ENABLED
                  value: "true"
              ports:
                - name: ui
                  containerPort: 16686
                - name: otlp-grpc
                  containerPort: 4317
                - name: otlp-http
                  containerPort: 4318
              resources:
                requests:
                  cpu: 50m
                  memory: 128Mi
                limits:
                  cpu: 500m
                  memory: 512Mi
  YAML

  depends_on = [kubectl_manifest.jaeger_service]
}

moved {
  from = kubectl_manifest.jaeger
  to   = kubectl_manifest.jaeger_service
}

# Internal NLB so workload ADOT / Promtail reach Jaeger OTLP over VPC peering
resource "kubectl_manifest" "jaeger_otlp_lb" {
  count = var.enable_obs_backend ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: v1
    kind: Service
    metadata:
      name: jaeger-otlp-lb
      namespace: ${var.observability_namespace}
      annotations:
        service.beta.kubernetes.io/aws-load-balancer-scheme: "internal"
        service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
        service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "instance"
    spec:
      type: LoadBalancer
      selector:
        app: jaeger
      ports:
        - name: otlp-grpc
          port: 4317
          targetPort: 4317
  YAML

  depends_on = [kubectl_manifest.jaeger_deployment]
}

resource "time_sleep" "wait_for_telemetry_lb" {
  count = var.enable_obs_backend ? 1 : 0

  create_duration = "90s"

  depends_on = [
    module.eks_addons,
    helm_release.loki,
    kubectl_manifest.jaeger_otlp_lb,
  ]
}

data "kubernetes_service_v1" "prometheus_lb" {
  count = var.enable_obs_backend ? 1 : 0

  metadata {
    name      = "${var.kube_prometheus_release_name}-kube-prometheus-prometheus"
    namespace = var.monitoring_namespace
  }

  depends_on = [time_sleep.wait_for_telemetry_lb]
}

data "kubernetes_service_v1" "loki_lb" {
  count = var.enable_obs_backend ? 1 : 0

  metadata {
    name      = "loki"
    namespace = var.observability_namespace
  }

  depends_on = [time_sleep.wait_for_telemetry_lb]
}

data "kubernetes_service_v1" "jaeger_otlp_lb" {
  count = var.enable_obs_backend ? 1 : 0

  metadata {
    name      = "jaeger-otlp-lb"
    namespace = var.observability_namespace
  }

  depends_on = [time_sleep.wait_for_telemetry_lb]
}

locals {
  obs_prometheus_lb_host = var.enable_obs_backend ? try(data.kubernetes_service_v1.prometheus_lb[0].status[0].load_balancer[0].ingress[0].hostname, "") : ""
  obs_loki_lb_host       = var.enable_obs_backend ? try(data.kubernetes_service_v1.loki_lb[0].status[0].load_balancer[0].ingress[0].hostname, "") : ""
  obs_jaeger_lb_host     = var.enable_obs_backend ? try(data.kubernetes_service_v1.jaeger_otlp_lb[0].status[0].load_balancer[0].ingress[0].hostname, "") : ""

  prometheus_remote_write_url = var.cluster_role == "obs" ? "http://${var.kube_prometheus_release_name}-kube-prometheus-prometheus.${var.monitoring_namespace}.svc.cluster.local:9090/api/v1/write" : var.obs_prometheus_remote_write_url
  jaeger_otlp_endpoint        = var.cluster_role == "obs" ? "jaeger.${var.observability_namespace}.svc.cluster.local:4317" : var.obs_jaeger_otlp_endpoint
  loki_push_url               = var.cluster_role == "obs" ? "http://loki.${var.observability_namespace}.svc.cluster.local:3100/loki/api/v1/push" : var.obs_loki_push_url
  telemetry_cluster_label     = var.cluster_role == "workload" ? "retail-workload" : "obs"
}
