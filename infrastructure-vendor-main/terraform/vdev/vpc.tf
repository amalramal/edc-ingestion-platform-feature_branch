module "vpc" {
  # source = "git::git@github.com:ledgerrun/terraform-modules.git?ref=vpc/v2.0.0"
  source = "git::git@github.com:ledgerrun/terraform-modules.git//vpc?ref=AD-CTMS-14591-single-nat-gateway"

  public_subnet_newbits  = 3
  private_subnet_newbits = 6

  aws_region   = var.aws_region
  project_name = var.environment
  vpc_cidr     = var.vpc_cidr

  enable_single_nat_gw = true
}
