vpc_cidr = "10.20.0.0/16"
azs = ["us-east-1a", "us-east-1b", "us-east-1c"]
private_subnets = [ "10.20.1.0/24", "10.20.4.0/24"]
public_subnets = ["10.20.10.0/24", "10.20.14.0/24"]
environment = "qa"
key_name = "aws_lab_key"
instance_type = "t2.micro"
ami = "ami-04b4f1a9cf54c11d0"