apiVersion: opentelemetry.io/v1alpha1
kind: OpenTelemetryCollector
metadata:
  name: adot-collector
  namespace: opentelemetry-operator-system
spec:
  mode: deployment
  serviceAccount: adot-collector
  config: |
    receivers:
      prometheus:
        config:
          scrape_configs:
            - job_name: kubernetes-pods
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
                  regex: ([^:]+)(?::\d+)?;(\d+)
                  replacement: $$1:$$2
                  target_label: __address__
                - action: labelmap
                  regex: __meta_kubernetes_pod_label_(.+)
                - source_labels: [__meta_kubernetes_namespace]
                  action: replace
                  target_label: namespace
                - source_labels: [__meta_kubernetes_pod_name]
                  action: replace
                  target_label: pod
%{ if enable_infra_metrics_export ~}
            - job_name: kube-state-metrics
              honor_labels: true
              kubernetes_sd_configs:
                - role: endpoints
                  namespaces:
                    names:
                      - ${monitoring_namespace}
              relabel_configs:
                - source_labels: [__meta_kubernetes_service_name]
                  action: keep
                  regex: kube-state-metrics
                - source_labels: [__meta_kubernetes_endpoint_port_name]
                  action: keep
                  regex: http
            - job_name: kubernetes-nodes-cadvisor
              scheme: https
              tls_config:
                ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
                insecure_skip_verify: true
              bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
              kubernetes_sd_configs:
                - role: node
              relabel_configs:
                - action: labelmap
                  regex: __meta_kubernetes_node_label_(.+)
                - target_label: __address__
                  replacement: kubernetes.default.svc:443
                - source_labels: [__meta_kubernetes_node_name]
                  regex: (.+)
                  target_label: __metrics_path__
                  replacement: /api/v1/nodes/$$1/proxy/metrics/cadvisor
                - source_labels: [__meta_kubernetes_node_name]
                  action: replace
                  target_label: node
              metric_relabel_configs:
                - source_labels: [__name__]
                  regex: container_(cpu|memory|network|fs).*
                  action: keep
%{ endif ~}
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
    processors:
      batch: {}
      resource:
        attributes:
          - key: cluster
            value: ${cluster_label}
            action: upsert
    exporters:
      prometheusremotewrite:
        endpoint: ${prometheus_remote_write_url}
        resource_to_telemetry_conversion:
          enabled: true
      otlp:
        endpoint: ${jaeger_otlp_endpoint}
        tls:
          insecure: true
    service:
      pipelines:
        metrics:
          receivers: [prometheus]
          processors: [batch, resource]
          exporters: [prometheusremotewrite]
        traces:
          receivers: [otlp]
          processors: [batch, resource]
          exporters: [otlp]
