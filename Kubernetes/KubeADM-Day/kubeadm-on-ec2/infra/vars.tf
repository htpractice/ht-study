# variables.tf file is used to define the variables that are used in the Terraform modules.
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default = "10.100.0.0/16"
}

variable "azs" {
  description = "Availability Zones"
  type        = list(string)
  default = ["us-west-2a", "us-west-2b"]
}

variable "allow_ssh_from_cidr_blocks" {
  description = "The CIDR blocks allowed to SSH into the EC2 instance"
  type = list(string)
  default = [ "172.225.137.213/32"]
}

variable "environment" {
  description = "Environment"
  type        = string
  default = "default"
}

variable "private_subnets" {
  description = "Private subnets"
  type        = list(string)
  default = ["10.100.1.0/24", "10.100.4.0/24"]
}

variable "public_subnets" {
  description = "Public subnets"
  type        = list(string)
  default = ["10.100.100.0/24", "10.100.104.0/24"]
}

#ec2 variables
variable "instance_type" {
  description = "The type of instance to launch"
  default = "t2.medium"  
}

variable "ami" {
  description = "The AMI to use"
  default = "ami-04b4f1a9cf54c11d0"
}

variable "worker_count" {
  description = "Number of kubeadm worker nodes"
  type        = number
  default     = 3
}

variable "app_count" {
  description = "Legacy — use worker_count + 1 control plane"
  default     = 4
}

variable "windows_ami" {
  description = "AMI ID for the Windows instances"
  default = "ami-07fa5275316057f54"
  type        = string
}

variable "windows_instance_type" {
  description = "Instance type for the Windows instances"
  default     = "t3.micro"
  type        = string
}

variable "my_local_IP" {
  description = "Optional override for SSH CIDR; SG uses data.http.self_ip if not set"
  type        = string
  default     = ""
}