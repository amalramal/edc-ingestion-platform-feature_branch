terraform {
  backend "s3" {
    bucket       = "ledgerrun-vendor-terraform-state"
    key          = "account/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
    profile      = "vendor-admin"
  }
}
