module "my_vpc" {
  source = "git::git@github.com:ledgerrun/terraform-modules.git?ref=vpc/vX.Y.Z"

  aws_region   = "us-east-0"
  project_name = "alpha"
  vpc_cidr     = "192.168.64.0/18"

  vpc_tags = {
    project     = "ledgerrun"
    account     = "<ACCOUNT NAME>"
    environment = "<ENVIRONMENT>"
    layer       = "networking"
    managedby   = "terraform"
  }
}
