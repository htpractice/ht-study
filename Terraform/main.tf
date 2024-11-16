module "ec2_instance" {
    source = "./modules/ec2"
    ami = var.ami
    subnet = var.subnet_id
    instance_type = lookup(var.aws_instance_type, terraform.workspace, "t2.micro")
}