# Upstream reference material (clone locally)

These are **optional** kind/local labs — not committed (nested `.git`). Clone when you want them:

```bash
cd observability

# Kind: Loki + Prometheus + Grafana + Promtail
git clone https://github.com/chrislusf/loki-prometheus-grafana-kubernetes-logging-monitoring.git

# Local PromQL / FastAPI demo
git clone https://github.com/jaegertracing/prometheus-docker-compose.git prometheus-docker-compose

# Spring Boot + ServiceMonitor pattern
git clone https://github.com/bibinwalter/application-monitoring-prometheus.git
```

Your canonical multicluster lab is **Terraform on EKS** in this branch — see [LAB-SPEC.md](./LAB-SPEC.md).
