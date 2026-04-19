module "waf_alb" {
  source = "git::git@github.com:ledgerrun/terraform-modules.git?ref=waf_alb/vX.Y.Z"

  name                 = "${var.realm}-${var.environment}"
  alb_arn              = var.alb_arn
  allowed_path_regexes = var.waf_allowed_path_regexes
  rate_limit           = var.waf_rate_limit
  managed_rule_action  = var.waf_managed_rule_action

  tags = {
    Realm       = var.realm
    Environment = var.environment
  }
}
