# S3 + DynamoDB for remote state (provider is in ../provider.tf)
resource "aws_s3_bucket" "terraform_state_bucket" {
    bucket = "kubeadm-on-ec2-terraform-state"
    tags = {
        Name = "terraform-state-bucket"
        ManagedBy = "Terraform"
        Terraform = "true"
        Environment = "dev"
    }
}

# Add ownership controls to enable ACLs
resource "aws_s3_bucket_ownership_controls" "ownership" {
    bucket = aws_s3_bucket.terraform_state_bucket.id
    rule {
        object_ownership = "BucketOwnerPreferred"
    }
}

# Then configure the ACL (this must come after ownership controls)
resource "aws_s3_bucket_acl" "bucket_acl" {
    depends_on = [aws_s3_bucket_ownership_controls.ownership]
    bucket = aws_s3_bucket.terraform_state_bucket.id
    acl    = "private"
}

# Versioning configuration
resource "aws_s3_bucket_versioning" "versioning" {
    bucket = aws_s3_bucket.terraform_state_bucket.id
    versioning_configuration {
        status = "Enabled"
    }
}

# DynamoDB table for state locking
module "tf_dyna_db" {
  source = "terraform-aws-modules/dynamodb-table/aws"
  name = "terraform-state-lock"
  hash_key = "LockID"  # Required for Terraform state locking
  billing_mode = "PAY_PER_REQUEST"
  attributes = [
    {
      name = "LockID"
      type = "S"
    }
  ]
  tags = {
    Name = "terraform-state-lock"
    ManagedBy = "Terraform"
    Terraform = "true"
    Environment = "dev"
  }
}