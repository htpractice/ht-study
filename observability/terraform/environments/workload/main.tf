terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket       = "obs-on-eks-tfstate-workload-725335002991"
    key          = "environments/eks-workload/terraform.tfstate"
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

data "terraform_remote_state" "obs" {
  backend = "s3"
  config = {
    bucket = "obs-on-eks-tfstate-obs-725335002991"
    key    = "environments/eks-obs/terraform.tfstate"
    region = var.aws_region
  }
}

locals {
  retail_store_argocd = abspath("${path.module}/../../../../../retail-store-sample-app/argocd")
  obs_telemetry       = try(data.terraform_remote_state.obs.outputs.telemetry_endpoints, {})
}

module "cluster" {
  source = "../../modules/eks-cluster"

  aws_region                = var.aws_region
  cluster_name              = var.cluster_name
  cluster_role              = "workload"
  environment               = var.environment
  kubernetes_version        = var.kubernetes_version
  vpc_cidr                  = var.vpc_cidr
  enable_single_nat_gateway = var.enable_single_nat_gateway
  peer_vpc_cidr             = var.obs_vpc_cidr

  enable_ingress_nginx         = true
  enable_kube_prometheus_stack = false
  enable_obs_backend           = false
  enable_adot                  = true
  enable_promtail              = true
  enable_infra_metrics_export  = true
  enable_argocd                = true
  argocd_root_path             = local.retail_store_argocd

  obs_prometheus_remote_write_url = try(local.obs_telemetry.prometheus_remote_write, var.obs_prometheus_remote_write_url)
  obs_loki_push_url               = try(local.obs_telemetry.loki_push, var.obs_loki_push_url)
  obs_jaeger_otlp_endpoint        = try(local.obs_telemetry.jaeger_otlp, var.obs_jaeger_otlp_endpoint)

  tags = var.tags
}
