terraform {
  backend "s3" {
    bucket       = "cka-2026-study-terraform-state-obs"
    key          = "environments/obs/terraform.tfstate"
    region       = "us-west-2"
    use_lockfile = true
    encrypt      = true
  }
}
