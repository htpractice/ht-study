variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "cluster_name" {
  type    = string
  default = "retail-obs"
}

variable "environment" {
  type    = string
  default = "lab"
}

variable "kubernetes_version" {
  type    = string
  default = "1.33"
}

variable "vpc_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "workload_vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "enable_single_nat_gateway" {
  type    = bool
  default = true
}

variable "tags" {
  type = map(string)
  default = {
    Lab     = "obs-on-eks"
    Cluster = "obs"
  }
}
