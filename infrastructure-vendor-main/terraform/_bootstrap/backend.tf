terraform {
  backend "s3" {
    bucket       = "ledgerrun-vendor-terraform-state"
    key          = "ledgerrun-vendor/bootstrap/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
    profile      = "vendor-admin"
  }
}
