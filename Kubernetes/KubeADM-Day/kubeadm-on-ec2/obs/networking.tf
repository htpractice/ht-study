#------------------VPC and Subnets-------------------
# Create a VPC with public and private subnets
module "cicd-lab-vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = ">= 3.0.0"
  name = "${var.environment}-vpc"
  cidr = var.vpc_cidr
  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  nat_gateway_tags = {
    Name = "${var.environment}-nat-gateway"
    Environment = var.environment
  }
  igw_tags = {
    Name = "${var.environment}-igw"
    Environment = var.environment
  }
  public_route_table_tags = {
    Name = "${var.environment}-public-rt"
    Environment = var.environment
  }
  private_route_table_tags = {
    Name = "${var.environment}-private-rt"
    Environment = var.environment
  }
  single_nat_gateway = true #Only 1 NAT Gateway (in AZ-a) will be created if true, otherwise one NAT Gateway per AZ
  enable_nat_gateway = true #NAT Gateway will be created if true
  tags = {
    "Terraform" = "true"
    "Environment" = var.environment
  }
}
#--------------------Creating Security Groups--------------------
# SSH CIDR from tfvars (never use data.http.self_ip — CI apply uses runner IP).
module "kubeadm_control_plane_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "6.0.0"
  name        = "${var.environment}-kubeadm-control-plane-sg"
  description = "Security group for Kubeadm Control Plane"
  vpc_id      = module.cicd-lab-vpc.vpc_id
  ingress_rules = {
    "6443-tcp-all" = {
      from_port   = 6443
      to_port     = 6443
      ip_protocol = "tcp"
      description = "Kubernetes API server"
      cidr_ipv4 = var.vpc_cidr
    }
    "SSH-from-laptop" = {
      from_port   = 22
      to_port     = 22
      ip_protocol = "tcp"
      description = "SSH from operator laptop"
      cidr_ipv4   = var.allow_ssh_from_cidr_blocks[0]
    }
    "flannel-vxlan-udp" = {
      from_port   = 8472
      to_port     = 8472
      ip_protocol = "udp"
      description = "Flannel VXLAN — required for cross-node pod traffic"
      cidr_ipv4   = var.vpc_cidr
    }
    "2379-2380-tcp" = {
      from_port   = 2379
      to_port     = 2380
      ip_protocol = "tcp"
      description = "etcd server & apiserver to client API"
      cidr_ipv4 = var.vpc_cidr
    }
    "10250-tcp" = {
      from_port   = 10248
      to_port     = 10259
      ip_protocol = "tcp"
      description = "Kubelet API & Kubelet to Kubelet Communication"
      cidr_ipv4 = var.vpc_cidr
    }
    "node-exporter-tcp" = {
      from_port   = 9100
      to_port     = 9100
      ip_protocol = "tcp"
      description = "Prometheus node-exporter scrape (cross-node)"
      cidr_ipv4   = var.vpc_cidr
    }
    "179-bgp-tcp" = {
      from_port   = 179
      to_port     = 179
      ip_protocol = "tcp"
      description = "BGP"
      cidr_ipv4 = var.vpc_cidr
    }
  }
  egress_rules = {
        "all" = {
          ip_protocol = "all"
          cidr_ipv4   = "0.0.0.0/0"
        }
      }
      tags = {
        "Name" = "${var.environment}-kubeadm-control-plane-sg"
        "Terraform" = "true"
        "Environment" = var.environment
      }
    }

# worker node security group
module "kubeadm_worker_node_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "6.0.0"
  name        = "${var.environment}-kubeadm-worker-node-sg"
  description = "Security group for Kubeadm Worker Node"
  vpc_id      = module.cicd-lab-vpc.vpc_id
  ingress_rules = {
    "SSH-from-laptop" = {
      from_port   = 22
      to_port     = 22
      ip_protocol = "tcp"
      description = "SSH from operator laptop"
      cidr_ipv4   = var.allow_ssh_from_cidr_blocks[0]
    }
    "flannel-vxlan-udp" = {
      from_port   = 8472
      to_port     = 8472
      ip_protocol = "udp"
      description = "Flannel VXLAN — required for cross-node pod traffic"
      cidr_ipv4   = var.vpc_cidr
    }
    "10250-tcp" = {
      from_port   = 10248
      to_port     = 10259
      ip_protocol = "tcp"
      description = "Kubelet API & Kubelet to Kubelet Communication"
      cidr_ipv4 = var.vpc_cidr
    }
    "node-exporter-tcp" = {
      from_port   = 9100
      to_port     = 9100
      ip_protocol = "tcp"
      description = "Prometheus node-exporter scrape (cross-node)"
      cidr_ipv4   = var.vpc_cidr
    }
    "30000-32767-tcp" = {
      from_port   = 30000
      to_port     = 32767
      ip_protocol = "tcp"
      description = "NodePort"
      cidr_ipv4 = var.vpc_cidr
    }
    "30000-32767-udp" = {
      from_port   = 30000
      to_port     = 32767
      ip_protocol = "udp"
      description = "NodePort"
      cidr_ipv4 = var.vpc_cidr
    }
    "179-bgp-tcp" = {
      from_port   = 179
      to_port     = 179
      ip_protocol = "tcp"
      description = "BGP"
      cidr_ipv4 = var.vpc_cidr
    }
  }
  egress_rules = {
        "all" = {
          ip_protocol = "all"
          cidr_ipv4   = "0.0.0.0/0"
        }
  }
      tags = {
        "Name" = "${var.environment}-kubeadm-worker-node-sg"
        "Terraform" = "true"
        "Environment" = var.environment
      }
    }