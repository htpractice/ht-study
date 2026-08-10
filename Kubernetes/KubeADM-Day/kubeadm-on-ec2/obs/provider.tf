terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  # No profile — GHA uses AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY; locally use default creds or AWS_PROFILE

  default_tags {
    tags = {
      Environment = var.environment
      ClusterRole = var.cluster_role
      ManagedBy   = "terraform"
      Project     = "kubeadm-lab"
    }
  }
}
