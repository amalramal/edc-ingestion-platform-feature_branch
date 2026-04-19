# data "aws_caller_identity" "current" {}

# data "aws_organizations_organization" "current" {}

# data "aws_organizations_account" "current" {
#   account_id = data.aws_caller_identity.current.account_id
# }

data "aws_route53_zone" "base_domain" {
  count        = var.create_alb ? 1 : 0
  name         = var.base_domain
  private_zone = false
}
