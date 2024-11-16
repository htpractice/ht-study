terraform {
  backend "s3" {
      region = "us"
      bucket = "<bucket name>"
      key = "<path to tfstate in S3>"
      dynamodb_table = "<hcl lock table name>"
  }
}