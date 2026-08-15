# SSH key — Terraform generates; you SSH from laptop with private_key.pem
resource "tls_private_key" "instance_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "${var.environment}-key"
  public_key = tls_private_key.instance_key.public_key_openssh
}

resource "local_file" "private_key_pem" {
  content         = tls_private_key.instance_key.private_key_pem
  filename        = "${path.module}/private_key.pem"
  file_permission = "0600"
}

# Control plane — kubeadm init runs here
module "control_plane" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "6.0.0"

  name                        = "${var.environment}-k8s-cp"
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = module.cicd-lab-vpc.public_subnets[0]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.generated_key.key_name

  vpc_security_group_ids  = [module.kubeadm_control_plane_sg.id]
  create_security_group   = false

  tags = {
    Name        = "${var.environment}-k8s-cp"
    Role        = "control-plane"
    Environment = var.environment
  }
}

# Workers — kubeadm join on each (default: 3)
locals {
  worker_names = [for i in range(var.worker_count) : format("w%d", i + 1)]
}

module "worker" {
  for_each = toset(local.worker_names)
  source   = "terraform-aws-modules/ec2-instance/aws"
  version  = "6.0.0"

  name                        = "${var.environment}-k8s-${each.key}"
  ami                         = var.ami
  instance_type               = var.instance_type
  # Spread workers across AZs when possible (w1→subnet0, w2→subnet1, w3→subnet0…)
  subnet_id                   = module.cicd-lab-vpc.public_subnets[index(local.worker_names, each.key) % length(module.cicd-lab-vpc.public_subnets)]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.generated_key.key_name

  vpc_security_group_ids = [module.kubeadm_worker_node_sg.id]
  create_security_group  = false

  tags = {
    Name        = "${var.environment}-k8s-${each.key}"
    Role        = "worker"
    Environment = var.environment
  }
}

# After apply: scp scripts/prep-node.sh to each node, then kubeadm init/join
# (Skip in-Terraform provisioners for kubeadm — prep-node.sh is clearer to learn)
