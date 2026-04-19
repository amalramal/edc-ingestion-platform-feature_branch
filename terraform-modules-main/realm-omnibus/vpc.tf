module "vpc" {
  count  = var.create_vpc ? 1 : 0
  source = "git::git@github.com:ledgerrun/terraform-modules.git?ref=vpc/v1.0.0"

  public_subnet_newbits  = 3
  private_subnet_newbits = 6

  aws_region   = var.aws_region
  project_name = "${var.realm}-${var.environment}"
  vpc_cidr     = var.vpc_cidr
}
