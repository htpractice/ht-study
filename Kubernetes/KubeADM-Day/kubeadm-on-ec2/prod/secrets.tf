# SSH private key — stored in AWS Secrets Manager (no local_file on CI runners).
resource "aws_secretsmanager_secret" "ssh_private_key" {
  name                    = "kubeadm/${var.environment}/ssh-private-key"
  description             = "EC2 SSH private key for kubeadm ${var.environment} cluster"
  recovery_window_in_days = 7

  tags = {
    Environment = var.environment
    ClusterRole   = var.cluster_role
    ManagedBy     = "terraform"
    Project       = "kubeadm-lab"
  }
}

resource "aws_secretsmanager_secret_version" "ssh_private_key" {
  secret_id     = aws_secretsmanager_secret.ssh_private_key.id
  secret_string = tls_private_key.instance_key.private_key_pem
}
