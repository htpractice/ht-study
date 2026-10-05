# SSH key — Terraform generates; private key in AWS Secrets Manager (see secrets.tf).
resource "tls_private_key" "instance_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "${var.environment}-key"
  public_key = tls_private_key.instance_key.public_key_openssh
}

locals {
  master_names = [for i in range(var.master_count) : format("m%d", i + 1)]
  worker_names = [for i in range(var.worker_count) : format("w%d", i + 1)]
}

# Control plane node(s) — kubeadm init on m1; HA: join m2+ with --control-plane
module "master" {
  for_each = toset(local.master_names)
  source   = "terraform-aws-modules/ec2-instance/aws"
  version  = "6.0.0"

  name                        = "${var.environment}-k8s-${each.key}"
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = module.cicd-lab-vpc.public_subnets[index(local.master_names, each.key) % length(module.cicd-lab-vpc.public_subnets)]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.generated_key.key_name

  vpc_security_group_ids = [module.kubeadm_control_plane_sg.id]
  create_security_group  = false

  tags = {
    Name        = "${var.environment}-k8s-${each.key}"
    Role        = "control-plane"
    Environment = var.environment
    ClusterRole = var.cluster_role
  }
}

module "worker" {
  for_each = toset(local.worker_names)
  source   = "terraform-aws-modules/ec2-instance/aws"
  version  = "6.0.0"

  name                        = "${var.environment}-k8s-${each.key}"
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = module.cicd-lab-vpc.public_subnets[index(local.worker_names, each.key) % length(module.cicd-lab-vpc.public_subnets)]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.generated_key.key_name

  vpc_security_group_ids = [module.kubeadm_worker_node_sg.id]
  create_security_group  = false

  tags = {
    Name        = "${var.environment}-k8s-${each.key}"
    Role        = "worker"
    Environment = var.environment
    ClusterRole = var.cluster_role
  }
}

# Bootstrap scripts staged via scripts.tf (file provisioner). SSH and run:
#   m1: sudo bash ~/prep-node-master.sh
#   workers: JOIN_CMD=... sudo -E bash ~/prep-node-worker.sh
