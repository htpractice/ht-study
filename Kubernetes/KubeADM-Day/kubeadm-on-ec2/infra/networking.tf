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
# Fetch the self IP using a public API
data "http" "self_ip" {
  url = "http://ipv4.icanhazip.com"
}

#Kubeadm Control Plane Security Group
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
    "SSH-from-self-IP"={
        from_port   = 22
        to_port     = 22
        ip_protocol = "tcp"
        description = "SSH from self IP"
        cidr_ipv4 = "${chomp(data.http.self_ip.response_body)}/32" # This will be the ip of your lab-server
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
    "SSH-from-self-IP"={
      from_port   = 22
      to_port     = 22
      ip_protocol = "tcp"
      description = "SSH from self IP"
      cidr_ipv4 = "${chomp(data.http.self_ip.response_body)}/32" # This will be the ip of your lab-server
    }
    "10250-tcp" = {
      from_port   = 10248
      to_port     = 10259
      ip_protocol = "tcp"
      description = "Kubelet API & Kubelet to Kubelet Communication"
      cidr_ipv4 = var.vpc_cidr
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