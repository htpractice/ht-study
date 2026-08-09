output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "cluster_role" {
  description = "app, obs, or tooling"
  value       = var.cluster_role
}

output "kubeconfig_hint" {
  description = "Suggested local kubeconfig filename"
  value       = "config-kubeadm-${var.environment}"
}

output "primary_master" {
  description = "Run kubeadm init on this master name"
  value       = "m1"
}

output "kubeadm_control_plane_sg_id" {
  description = "Control plane security group ID"
  value       = module.kubeadm_control_plane_sg.id
}

output "kubeadm_worker_node_sg_id" {
  description = "Worker security group ID"
  value       = module.kubeadm_worker_node_sg.id
}

output "master_public_ips" {
  description = "Map of master name → public IP"
  value       = { for name, inst in module.master : name => inst.public_ip }
}

output "control_plane_public_ip" {
  description = "Primary master (m1) public IP — backward compatible"
  value       = module.master["m1"].public_ip
}

output "ssh_masters" {
  description = "SSH commands for each master"
  value = {
    for name, inst in module.master :
    name => "ssh -i ${path.module}/private_key.pem ubuntu@${inst.public_ip}"
  }
}

output "ssh_control_plane" {
  description = "SSH command for primary master (m1)"
  value       = "ssh -i ${path.module}/private_key.pem ubuntu@${module.master["m1"].public_ip}"
}

output "worker_public_ips" {
  description = "Map of worker name → public IP"
  value       = { for name, inst in module.worker : name => inst.public_ip }
}

output "ssh_workers" {
  description = "SSH commands for each worker"
  value = {
    for name, inst in module.worker :
    name => "ssh -i ${path.module}/private_key.pem ubuntu@${inst.public_ip}"
  }
}

output "bootstrap_next_steps" {
  description = "Post-apply bootstrap from your laptop (SG allows your IP only)"
  value = var.copy_scripts_via_ssh ? <<-EOT
    m1: sudo bash ~/prep-node-master.sh
    workers: export JOIN_CMD='kubeadm join ...' && sudo -E bash ~/prep-node-worker.sh
    kubeconfig: ~/.kube/config-kubeadm-${var.environment}
  EOT
  : <<-EOT
    scripts: Kubernetes/KubeADM-Day/scripts/copy-scripts-to-nodes.sh ${var.environment}
    m1: sudo bash ~/prep-node-master.sh
    workers: export JOIN_CMD='kubeadm join ...' && sudo -E bash ~/prep-node-worker.sh
    kubeconfig: ~/.kube/config-kubeadm-${var.environment}
  EOT
}
