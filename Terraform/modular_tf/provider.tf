# provider file for the terraform module
terraform {
    required_providers {
        aws = {
        source  = "hashicorp/aws"
        version = "~> 3.0"
        }
    }
    backend "s3" {
        bucket = "terraform-state-practice-2025"
        key    = "terraform.tfstate"
        region = "us-east-1"
        dynamodb_table = "terraform-state-lock"
        encrypt = true
    }
}
provider "aws" {
  region = "us-east-1"
}