#
# This file does the following:
#   * Creates a new Hosted Zone: <REALM>-<ENV>.<BASEDOMAIN>
#   * Creates and Validates an ACM Certificate for
#       - REALM-ENV.BASEDOMAIN
#       - *.REALM-ENV.BASEDOMAIN
#

# New Hosted Zone for the Realm
resource "aws_route53_zone" "realm" {
  name = "${var.realm}-${var.environment}.${var.base_domain}"
}

# Add NS records for new zone to BASE_DOMAIN
resource "aws_route53_record" "realm_ns" {
  zone_id = data.aws_route53_zone.base_domain[0].zone_id
  name    = "${var.realm}-${var.environment}.${var.base_domain}"
  type    = "NS"
  ttl     = "60"
  records = aws_route53_zone.realm.name_servers
}

# ACM Certificate for ALB
resource "aws_acm_certificate" "cert" {
  count       = var.create_alb ? 1 : 0
  domain_name = "${var.realm}-${var.environment}.${var.base_domain}"
  subject_alternative_names = [
    "*.${var.realm}-${var.environment}.${var.base_domain}"
  ]
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# DNS Validation for Certificate
resource "aws_route53_record" "validation" {
  for_each = var.create_alb ? toset([
    "${var.realm}-${var.environment}.${var.base_domain}",
    "*.${var.realm}-${var.environment}.${var.base_domain}",
  ]) : toset([])

  allow_overwrite = true
  name            = one([for dvo in aws_acm_certificate.cert[0].domain_validation_options : dvo.resource_record_name if dvo.domain_name == each.key])
  records         = [one([for dvo in aws_acm_certificate.cert[0].domain_validation_options : dvo.resource_record_value if dvo.domain_name == each.key])]
  ttl             = 60
  type            = one([for dvo in aws_acm_certificate.cert[0].domain_validation_options : dvo.resource_record_type if dvo.domain_name == each.key])
  zone_id         = aws_route53_zone.realm.zone_id
}

# Validate the certificate
resource "aws_acm_certificate_validation" "validation" {
  certificate_arn         = aws_acm_certificate.cert[0].arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}
