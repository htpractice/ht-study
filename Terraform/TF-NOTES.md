### Raw notes for terraform

# Modules
- Provide redabiliy, reusability, managability, simplicity, versioning

eg :
terraform/
├── work/                     # Root module
│   ├── main.tf               # Root module configuration
│   ├── terraform.tfvars      # Environment-specific variables (e.g., dev, prod)
│   ├── backend.tf            # Backend configuration (optional but recommended here)
│   └── variables.tf          # Variable definitions
├── modules/
│   ├── compute/
│   │   ├── main.tf           # Child module template for EC2 instances
│   │   └── variables.tf      # Variables specific to compute module

- Backend Configuration: Needs to be in the root module (/terraform/work/). The child module (modules/compute) does not and should not have a backend configuration.
- State Management: Terraform uses the single state file configured in the root module to track all resources, including those from child modules.
- Variables: Pass environment-specific variables (like instance_type, count, etc.) from the root module to the child module via the module block.

# Backend
- Terraform tracks all resources, including those defined in the child module, in the state file stored in the backend (S3 in this case).
- The child module doesn’t create its own state file or interact directly with the backend.

                    terraform {
                      backend "s3" {
                        bucket = "bucket_s3"
                        key    = "work/tfstate"
                        region = "us-east-1"
                        dynamodb_table = "table"
                      }
                    }

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
- Lock is used on tfstate file to safeguard it from multiple execution at the sametime and maintain the versioning of provider used.

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

- The file provisioner copies files or directories from the machine running Terraform to the newly created resource.

    provisioner "file" {
        source = <>
        destination = <>
        connection {
            type = ssh
            private_key = aws_key_pair.example.key_value -> if its created under same terraform execution in aws
            user = ubuntu
        }
    }

- The remote-exec provisioner invokes a script on a remote resource after it is created.

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

- The local-exec provisioner invokes a local executable after a resource is created.

        resource "aws_instance" "web" {
          # ...

          provisioner "local-exec" {
            command = "echo $FOO $BAR $BAZ >> env_vars.txt"

            environment = {
              FOO = "bar"
              BAR = 1
              BAZ = "true"
            }
          }
        }


# Terraform Workspaces
- maintains the statefile per env.
- don't allow tfstate files to overlap each other based on env.
- if we have 3 env or 3 workspaces terraform will create a terraform.d or similar folder to store env specific statefile and that is updated when any changes are made in that env.
- terraform workspace new dev -> this will create folder terraform.d in main terraform project folder inside which we will see dev folder.
- terraform workspace select < workspace name > -> this will change workspace.
- terraform apply -var-file=< env spcific var file > -> this way we don't have to edit same file again and again.
- state file in terraform workspaces will be remote if the backend.tf is configured and they will seperately stored under workspace name in backedn S3 or consul or azure blob storage etc.
- following backend config will be needed for storing workspace specific statefiles
                    terraform {
                      backend "s3" {
                        bucket         = "my-terraform-bucket"          # S3 bucket for state file
                        key            = "path/to/state/${terraform.workspace}/tfstate"  # Workspace-aware key
                        region         = "us-east-1"                   # AWS region
                        dynamodb_table = "terraform-lock-table"        # DynamoDB table for locking
                        encrypt        = true                          # Encrypt state file in S3
                      }
                    }


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
        1 . terraform refresh (refreshes the statefile to look for any changes in state file which needs to be run as cron job.)

        2 . Configure strict IAM rules and have super user to manage the resources ... may be allow users to have use access.
            Setup audit logs and maybe we can setup some automation via functions if there is any manual change is made and if the resource is managed by terraform, and who made it, immediately notify.