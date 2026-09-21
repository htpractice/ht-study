config:
  clients:
    - url: ${loki_push_url}
      external_labels:
        cluster: ${cluster_label}
  snippets:
    extraRelabelConfigs:
      - action: replace
        target_label: cluster
        replacement: ${cluster_label}

daemonset:
  enabled: true

resources:
  requests:
    cpu: 50m
    memory: 64Mi
