variable "aws_region" {
  description = "AWS region for EKS lab"
  type        = string
  default     = "ap-south-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "cicd-day-eks"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.30"
}

variable "node_instance_types" {
  description = "Worker instance types"
  type        = list(string)
  default     = ["t3.small"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "tags" {
  type = map(string)
  default = {
    Project = "cicd-day-lab"
    Owner   = "harshal"
  }
}
