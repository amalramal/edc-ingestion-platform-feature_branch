module "alb" {
  count  = var.create_alb ? 1 : 0
  source = "git::git@github.com:ledgerrun/terraform-modules.git?ref=alb/v1.0.0"
  #   source = "/Users/aduss/ledgerrun/terraform-modules/alb"

  name       = "${var.realm}-${var.environment}"
  vpc_id     = module.vpc[0].vpc_id
  subnet_ids = module.vpc[0].public_subnet_ids

  certificate_arn = aws_acm_certificate.cert[0].arn
}
