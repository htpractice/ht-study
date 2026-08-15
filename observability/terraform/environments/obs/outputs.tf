output "cluster_name" {
  value = module.cluster.cluster_name
}

output "cluster_endpoint" {
  value = module.cluster.cluster_endpoint
}

output "vpc_id" {
  value = module.cluster.vpc_id
}

output "vpc_cidr_block" {
  value = module.cluster.vpc_cidr_block
}

output "private_route_table_ids" {
  value = module.cluster.private_route_table_ids
}

output "public_route_table_ids" {
  value = module.cluster.public_route_table_ids
}

output "configure_kubectl" {
  value = module.cluster.configure_kubectl
}

output "prometheus_remote_write_url" {
  value = module.cluster.prometheus_remote_write_url
}

output "loki_push_url" {
  value = module.cluster.loki_push_url
}

output "jaeger_otlp_endpoint" {
  value = module.cluster.jaeger_otlp_endpoint
}

output "telemetry_endpoints" {
  value = module.cluster.telemetry_endpoints
}

output "grafana_port_forward" {
  value = module.cluster.grafana_url
}
