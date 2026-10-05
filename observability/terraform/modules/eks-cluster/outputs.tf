output "cluster_name" {
  description = "EKS cluster name with suffix"
  value       = module.eks.cluster_name
}

output "cluster_name_suffix" {
  value = random_string.suffix.result
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "cluster_version" {
  value = module.eks.cluster_version
}

output "cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}

output "cluster_oidc_issuer_url" {
  value = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "node_security_group_id" {
  value = module.eks.node_security_group_id
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  value = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "private_route_table_ids" {
  value = module.vpc.private_route_table_ids
}

output "public_route_table_ids" {
  value = module.vpc.public_route_table_ids
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name} --alias ${var.cluster_role}-eks"
}

output "argocd_server_port_forward" {
  value = "kubectl port-forward svc/argocd-server -n ${var.argocd_namespace} 8080:443"
}

output "argocd_admin_password" {
  value     = "kubectl -n ${var.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
  sensitive = true
}

output "ingress_nginx_loadbalancer" {
  value = "kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}

output "retail_store_url" {
  value = "echo 'http://'$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
}

output "grafana_url" {
  value = var.enable_kube_prometheus_stack ? "kubectl port-forward -n ${var.monitoring_namespace} svc/${var.kube_prometheus_release_name}-grafana 3000:80" : ""
}

output "prometheus_remote_write_url" {
  description = "Remote write URL for cross-cluster ADOT (internal NLB)"
  value       = var.enable_obs_backend && local.obs_prometheus_lb_host != "" ? "http://${local.obs_prometheus_lb_host}:9090/api/v1/write" : ""
}

output "loki_push_url" {
  description = "Loki push URL for cross-cluster Promtail"
  value       = var.enable_obs_backend && local.obs_loki_lb_host != "" ? "http://${local.obs_loki_lb_host}:3100/loki/api/v1/push" : ""
}

output "jaeger_otlp_endpoint" {
  description = "Jaeger OTLP gRPC endpoint for cross-cluster ADOT traces"
  value       = var.enable_obs_backend && local.obs_jaeger_lb_host != "" ? "${local.obs_jaeger_lb_host}:4317" : ""
}

output "telemetry_endpoints" {
  value = {
    prometheus_remote_write = var.enable_obs_backend && local.obs_prometheus_lb_host != "" ? "http://${local.obs_prometheus_lb_host}:9090/api/v1/write" : local.prometheus_remote_write_url
    loki_push               = var.enable_obs_backend && local.obs_loki_lb_host != "" ? "http://${local.obs_loki_lb_host}:3100/loki/api/v1/push" : local.loki_push_url
    jaeger_otlp             = var.enable_obs_backend && local.obs_jaeger_lb_host != "" ? "${local.obs_jaeger_lb_host}:4317" : local.jaeger_otlp_endpoint
    cluster_label           = local.telemetry_cluster_label
  }
}
