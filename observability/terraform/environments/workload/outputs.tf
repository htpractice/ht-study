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

output "argocd_admin_password" {
  value     = module.cluster.argocd_admin_password
  sensitive = true
}

output "retail_store_url" {
  value = module.cluster.retail_store_url
}

output "ingress_nginx_loadbalancer" {
  value = module.cluster.ingress_nginx_loadbalancer
}
