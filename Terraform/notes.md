### Raw notes for terraform

# Modules
- Provide redabiliy, reusability, managability, simplicity, versioning

# States in Terraform
- Used to store resources created by terraform
- can be local as well as remote
- drawback of local is it can be mutated easily and can cause issue for future deployments and needs to manage versioning by pushing everytime to repo.
- Use of remote safegaurd the mutation and versioning, everytime the code is chnaged and run tfstate gets updated post resource PR merge.
- we can use following block to do so
    terraform {
        backend "s3"{
            bucket = "bucket_name"
            region = "aws/oci region"
            key = "< path to store terraform.tfstate in bucket >
            dynamodb_table = " < name of the table used to store lock > "
        }
    }
- Lock is used on tfstate file to safeguard it from multiple execution at the sametime and maintain the versioning of proider used.

# Provsioners
- They are use to provision the files or execute commands on the EC2 for specific project or need
- Provisioner types are file , remote_exec , local_exec
- following is example provsioner block
    resource "aws_ec2_instance" "example"{
        ami = "amiID"
        type = "instance type"
        subnet = "subnet_id"
        .
        .
        .
    }

    provisioner "file" {
        source = <>
        destination = <>
        connection {
            type = ssh
            private_key = aws_key_pair.example.key_value -> if its created under same terraform execution in aws
            user = ubuntu
        }
    }

    provisioner remote_exec {
        inline [
            echo "Hi"
            yum install -y yum
        ]
        connection {
            type = ssh
            private_key = file("~/.ssh/id_rsa")   -> if its stored in local
            user = ubuntu
            host = aws_instance.example.public_ip
        }
    }

# Terraform Workspaces
- maintains the statefile per env.
- don't allow tfstate files to overlap each other based on env.
- if we have 3 env or 3 workspaces terraform will create a terraform.d or similar folder to store env specific statefile and that is updated when any changes are made in that env.
- terraform workspace new dev -> this will create folder terraform.d in main terraform project folder inside which we will see dev folder.
- terraform workspace select < workspace name > -> this will change workspace.
- terraform apply -var-file=< env spcific var file > -> this way we don't have to edi same file again and again.
- state file in terraform workspaces will be remote if the backend.tf is configured and they will seperately stored under workspace name in backedn S3 or consul or azure blob storage etc.


#### Interview Related Questions ####

# How to import the resources?
-  using import block
- create a import block config and run tf init tf plan -generate-config-out=< name of resource file>.tf
        provider "aws" {
            region = "us-east-1"
        }

        import {
            id = "instanceid"
            to = aws_instance.imported_instance
        }
- once the import file is created now we need the terraform state file for keeping this istance as it is and not recreate in next terraform run, we can do that using below command
        terraform import aws_instance.example < instance id >

# You have created an ec2 instnace and new people join in and now you have 100's of resources. One of the bucket meets with an issue, and colluge alters it from AWS cosole for just once customer what will you do? consider everything is on tf.
- This scenario is called as drift and detecting it using terraform is call drift detection.
- We can use
        1 - terraform refresh (refreshes the statefile to look for any changes in state file which needs to be run as cron job.)