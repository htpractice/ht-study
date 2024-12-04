provider "aws" {
  region = "us-east-1"
}

import {
    id = "instanceid"
    to = aws_instance.imported_instance
}