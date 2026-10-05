output "kubeadm_control_plane_sg_id" {
  description = "Control plane security group ID"
  value       = module.kubeadm_control_plane_sg.id
}

output "kubeadm_worker_node_sg_id" {
  description = "Worker security group ID"
  value       = module.kubeadm_worker_node_sg.id
}

output "control_plane_public_ip" {
  description = "SSH target for kubeadm init"
  value       = module.control_plane.public_ip
}

output "ssh_control_plane" {
  description = "SSH command for control plane"
  value       = "ssh -i ${path.module}/private_key.pem ubuntu@${module.control_plane.public_ip}"
}

output "worker_public_ips" {
  description = "Map of worker name → public IP for kubeadm join"
  value       = { for name, inst in module.worker : name => inst.public_ip }
}

output "ssh_workers" {
  description = "SSH commands for each worker"
  value = {
    for name, inst in module.worker :
    name => "ssh -i ${path.module}/private_key.pem ubuntu@${inst.public_ip}"
  }
}
