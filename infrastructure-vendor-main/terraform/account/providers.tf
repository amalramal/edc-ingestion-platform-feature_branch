provider "aws" {
  region  = var.aws_region
  profile = "vendor-admin"

  default_tags {
    tags = {
      Project    = "ledgerrun"
      Account    = "ledgerrun-vendor"
      env        = "global"
      Layer      = "infrastructure"
      ManagedBy  = "terraform"
      Repository = "infrastructure-ledgerrun"
    }
  }
}

provider "aws" {
  alias   = "clinrun"
  region  = "us-east-1"
  profile = "lr-production"
}
