resource "aws_route53_record" "svc" {
  zone_id = data.aws_route53_zone.realm.id
  name    = var.service_name
  type    = "CNAME"
  ttl     = 300
  records = [
    var.use_alb ? data.aws_lb.alb[0].dns_name : aws_lb.nlb[0].dns_name
  ]
}
