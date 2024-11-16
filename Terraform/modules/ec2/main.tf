resource "aws_instance" "workspace-example" {
  ami = var.ami
  provider = aws.east
  instance_type = var.aws_instance_type
  subnet = var.subnet_id
}

resource "aws_dynamodb_table" "hcl_lock" {
  name           = "terraform-lock"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
resource "aws_s3_bucket" "tfstate_bucket" {
  bucket = "unique-buckt-name"
}

resource "aws_instance" "name" {
  
}