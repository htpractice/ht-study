terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket       = "obs-on-eks-tfstate-obs-725335002991"
    key          = "environments/eks-obs/terraform.tfstate"
    region       = "us-west-2"
    use_lockfile = true
    encrypt      = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "cluster" {
  source = "../../modules/eks-cluster"

  aws_region                = var.aws_region
  cluster_name              = var.cluster_name
  cluster_role              = "obs"
  environment               = var.environment
  kubernetes_version        = var.kubernetes_version
  vpc_cidr                  = var.vpc_cidr
  enable_single_nat_gateway = var.enable_single_nat_gateway
  peer_vpc_cidr             = var.workload_vpc_cidr

  enable_ingress_nginx         = true
  enable_kube_prometheus_stack = true
  enable_obs_backend           = true
  enable_adot                  = true
  enable_promtail              = true
  enable_argocd                = false

  tags = var.tags
}
