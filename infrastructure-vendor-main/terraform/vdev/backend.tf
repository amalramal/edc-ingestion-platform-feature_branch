terraform {
  backend "s3" {
    bucket       = "ledgerrun-vendor-terraform-state"
    key          = "dev/infrastructure/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
    profile      = "vendor-poweruser"
  }
}
