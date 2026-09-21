variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "cluster_name" {
  type    = string
  default = "retail-workload"
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
  default = "10.0.0.0/16"
}

variable "obs_vpc_cidr" {
  description = "Obs cluster VPC — opened on node SG for cross-cluster scrape"
  type        = string
  default     = "10.1.0.0/16"
}

variable "enable_single_nat_gateway" {
  type    = bool
  default = true
}

variable "obs_prometheus_remote_write_url" {
  description = "Override if obs remote state unavailable"
  type        = string
  default     = ""
}

variable "obs_loki_push_url" {
  type    = string
  default = ""
}

variable "obs_jaeger_otlp_endpoint" {
  type    = string
  default = ""
}

variable "tags" {
  type = map(string)
  default = {
    Lab     = "obs-on-eks"
    Cluster = "workload"
  }
}
