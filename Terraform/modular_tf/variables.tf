# variables.tf file is used to define the variables that are used in the Terraform modules.
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default = "10.100.0.0/16"
}

variable "azs" {
  description = "Availability Zones"
  type        = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
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
  default = "t2.micro"  
}

variable "ami" {
  description = "The AMI to use"
  default = "ami-04b4f1a9cf54c11d0"
}

variable "count" {
  description = "The count of instances to launch"
  default = 3
}

variable "instance_map" {
  description = "The map of instances to launch"
  type = map(string)
  default = {
    "us-east-1a" = "0"
    "us-east-1b" = "1"
    #"us-east-1c" = "2"
  }
}