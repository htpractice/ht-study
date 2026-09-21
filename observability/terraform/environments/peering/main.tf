terraform {
  required_version = ">= 1.5"

  backend "s3" {
    bucket       = "obs-on-eks-tfstate-obs-725335002991"
    key          = "environments/eks-peering/terraform.tfstate"
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

data "terraform_remote_state" "workload" {
  backend = "s3"
  config = {
    bucket = "obs-on-eks-tfstate-workload-725335002991"
    key    = "environments/eks-workload/terraform.tfstate"
    region = var.aws_region
  }
}

data "terraform_remote_state" "obs" {
  backend = "s3"
  config = {
    bucket = "obs-on-eks-tfstate-obs-725335002991"
    key    = "environments/eks-obs/terraform.tfstate"
    region = var.aws_region
  }
}

module "peering" {
  source = "../../modules/vpc-peering"

  aws_region = var.aws_region
  name       = "obs-on-eks-workload-obs"

  requester_vpc_id = data.terraform_remote_state.workload.outputs.vpc_id
  accepter_vpc_id  = data.terraform_remote_state.obs.outputs.vpc_id

  requester_vpc_cidr = data.terraform_remote_state.workload.outputs.vpc_cidr_block
  accepter_vpc_cidr  = data.terraform_remote_state.obs.outputs.vpc_cidr_block

  requester_route_table_ids = concat(
    data.terraform_remote_state.workload.outputs.private_route_table_ids,
    data.terraform_remote_state.workload.outputs.public_route_table_ids,
  )

  accepter_route_table_ids = concat(
    data.terraform_remote_state.obs.outputs.private_route_table_ids,
    data.terraform_remote_state.obs.outputs.public_route_table_ids,
  )

  tags = var.tags
}

output "peering_connection_id" {
  value = module.peering.peering_connection_id
}
