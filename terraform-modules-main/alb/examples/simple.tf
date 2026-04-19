module "new_module" {
  source = "git::git@github.com:ledgerrun/terraform-modules.git?ref=alb/vX.Y.Z"

  name       = "${var.relam}-${var.environment}"
  vpc_id     = local.vpc_id
  subnet_ids = local.public_subnet_ids

  tags = {
    env = var.environment
  }
}
