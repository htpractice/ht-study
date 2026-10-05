variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "tags" {
  type = map(string)
  default = {
    Lab = "obs-on-eks"
  }
}
