provider "aws" {
  region  = var.aws_region
  profile = "vendor-poweruser"
  # profile = "vendor-admin"

  default_tags {
    tags = {
      Project    = "ledgerrun"
      Account    = "ledgerrun-vendor"
      env        = var.environment
      Layer      = "infrastructure"
      ManagedBy  = "terraform"
      Repository = "infrastructure-ledgerrun"
    }
  }
}
