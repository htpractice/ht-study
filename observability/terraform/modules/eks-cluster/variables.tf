variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "Base EKS cluster name (random suffix appended)"
  type        = string
}

variable "cluster_role" {
  description = "Cluster role label: workload or obs"
  type        = string
  validation {
    condition     = contains(["workload", "obs"], var.cluster_role)
    error_message = "cluster_role must be workload or obs."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "lab"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.33"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "enable_single_nat_gateway" {
  description = "Use single NAT gateway"
  type        = bool
  default     = true
}

variable "cluster_enabled_log_types" {
  description = "EKS control plane log types (empty = disabled for cost)"
  type        = list(string)
  default     = []
}

variable "enable_ingress_nginx" {
  description = "Install cert-manager + NGINX ingress via eks-blueprints-addons"
  type        = bool
  default     = true
}

variable "enable_kube_prometheus_stack" {
  description = "Install kube-prometheus-stack on this cluster (obs cluster)"
  type        = bool
  default     = false
}

variable "monitoring_namespace" {
  description = "Namespace for kube-prometheus-stack"
  type        = string
  default     = "monitoring"
}

variable "enable_argocd" {
  description = "Install ArgoCD and apply manifests from argocd_root_path"
  type        = bool
  default     = false
}

variable "argocd_root_path" {
  description = "Path to retail-store-sample-app/argocd directory"
  type        = string
  default     = ""
}

variable "argocd_namespace" {
  description = "ArgoCD namespace"
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "5.51.6"
}

variable "peer_vpc_cidr" {
  description = "Peer VPC CIDR for cross-cluster observability traffic"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional resource tags"
  type        = map(string)
  default     = {}
}

variable "enable_adot" {
  description = "Install ADOT EKS add-on and OpenTelemetryCollector"
  type        = bool
  default     = false
}

variable "adot_namespace" {
  description = "Namespace for ADOT operator and collector (EKS add-on default)"
  type        = string
  default     = "opentelemetry-operator-system"
}

variable "enable_promtail" {
  description = "Install Promtail DaemonSet for log shipping to Loki"
  type        = bool
  default     = false
}

variable "enable_obs_backend" {
  description = "Install central Loki + Jaeger on obs cluster"
  type        = bool
  default     = false
}

variable "observability_namespace" {
  description = "Namespace for Loki, Jaeger, Promtail"
  type        = string
  default     = "observability"
}

variable "kube_prometheus_release_name" {
  description = "Helm release name for kube-prometheus-stack"
  type        = string
  default     = "prometheus"
}

variable "obs_prometheus_remote_write_url" {
  description = "Workload only: obs Prometheus remote_write URL (from obs terraform output)"
  type        = string
  default     = ""
}

variable "obs_loki_push_url" {
  description = "Workload only: obs Loki push URL over VPC peering"
  type        = string
  default     = ""
}

variable "obs_jaeger_otlp_endpoint" {
  description = "Workload only: obs Jaeger OTLP host:4317 over VPC peering"
  type        = string
  default     = ""
}

variable "enable_infra_metrics_export" {
  description = "Workload only: install kube-state-metrics and scrape cAdvisor via ADOT for Grafana infra dashboards"
  type        = bool
  default     = false
}
