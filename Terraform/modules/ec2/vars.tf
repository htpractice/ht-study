variable "ami" {
  description = "This is AMI for instance"
  type = string
}

variable "aws_instance_type" {
  description = "This for ec2 instance type"
  type = map(string)
  default = {
    "dev" = "t2.micro"
    "stage" = "t2.medium"
    "prod"  = "t2.xlarge"
  }
}

variable "subnet" {
  description = "Subnet ID"
  type = string
}