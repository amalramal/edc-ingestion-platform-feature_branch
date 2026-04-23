variable "environment" {
  default = "vdev"
}

data "aws_route53_zone" "base_domain" {
  provider     = aws.clinrun
  name         = var.base_domain
  private_zone = false
}

resource "aws_route53_zone" "env" {
  name = "${var.environment}.${var.base_domain}"
}

# Add NS records for new zone to clinrun AWS account
resource "aws_route53_record" "realm_ns" {
  provider = aws.clinrun
  zone_id  = data.aws_route53_zone.base_domain.zone_id
  name     = "${var.environment}.${var.base_domain}"
  type     = "NS"
  ttl      = "60"
  records  = aws_route53_zone.env.name_servers
}
