provider "aws" {
  region  = var.aws_region
  profile = "vendor-admin"

  default_tags {
    tags = {
      Project    = "ledgerrun"
      Account    = "ledgerrun-vendor"
      env        = "dev"
      Layer      = "bootstrap"
      ManagedBy  = "terraform"
      Repository = "infrastructure-vendor"
    }
  }
}
