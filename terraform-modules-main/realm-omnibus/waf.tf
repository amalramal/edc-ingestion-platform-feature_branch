# WAF for ALB – attach when create_waf = true. Uses ALB from module.alb (create_alb must be true).
module "waf_alb" {
  count  = var.create_waf && var.create_alb ? 1 : 0
  source = "git::ssh://git@github.com/ledgerrun/terraform-modules.git?ref=waf_alb/v1.0.1"

  name                 = "${var.realm}-${var.environment}"
  alb_arn              = module.alb[0].alb_arn
  allowed_path_regexes = var.waf_allowed_path_regexes
  rate_limit           = var.waf_rate_limit
  managed_rule_action  = var.waf_managed_rule_action

  tags = {
    Realm       = var.realm
    Environment = var.environment
  }
}
