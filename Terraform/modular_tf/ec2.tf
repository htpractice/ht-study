module "bastion_ec2" {
  source = "terraform-aws-modules/ec2-instance/aws"
  for_each = {
    "us-east-1a" = 0,
    "us-east-1b" = 1,
    #"us-east-1c" = 2
    }
  name                   = "${var.environment}-bastion-${each.value + 1}"
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = "practice-lab-01"
  subnet_id              = module.vpc.public_subnets[each.value]
  vpc_security_group_ids     = [module.lab_security_group.security_group_id]
  associate_public_ip_address = true
  #user_data              = file("userdata.tpl")
  availability_zone = each.key
tags = {
    Terraform = "true"
    Environment = var.environment
  }
}

resource "null_resource" "local_provisioner" {
  depends_on = [module.bastion_ec2]

  provisioner "local-exec" {
            command = <<EOF
                cd Ansible
                ansible-playbook -i inventory_aws_ec2.yml install_docker.yaml
            EOF
            }
}

