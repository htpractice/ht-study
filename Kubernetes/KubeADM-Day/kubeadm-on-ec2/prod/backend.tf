terraform {
  backend "s3" {
    bucket       = "cka-2026-study-terraform-state-prod"
    key          = "environments/prod/terraform.tfstate"
    region       = "us-west-2"
    use_lockfile = true
    encrypt      = true
  }
}
