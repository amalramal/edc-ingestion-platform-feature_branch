provider "aws" {
  region  = "us-east-1"
  profile = "lr-production"

  default_tags {
    tags = {
      project     = "clinrun"
      account     = "clinrun-legacy"
      environment = "dev"
      layer       = "realm"
      managedby   = "terraform"
      realm       = "<REALM>"
    }
  }
}


module "realm" {
  source = "git::git@github.com:ledgerrun/terraform-modules.git?ref=<TEMPLATE>/vX.Y.Z"

  environment = "dev"
  realm       = "<REALM>"
  vpc_cidr    = "172.16.64.0/18"

  create_ecs_cluster = true
  options_ecs_cluster = {
    enable_container_insights = false
  }
}
