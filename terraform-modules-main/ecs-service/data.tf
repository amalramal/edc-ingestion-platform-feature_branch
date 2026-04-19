data "aws_region" "current" {}

data "aws_ecs_cluster" "realm" {
  cluster_name = local.realm_name
}

data "aws_caller_identity" "current" {}

data "aws_vpc" "vpc" {
  state = "available"
  filter {
    name   = "tag:Name"
    values = ["${local.realm_name}-vpc"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }

  filter {
    name   = "tag:NetworkType"
    values = ["private"]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }

  filter {
    name   = "tag:NetworkType"
    values = ["public"]
  }
}

data "aws_lb" "alb" {
  count = var.use_alb ? 1 : 0
  name  = "${local.realm_name}-alb"
}

data "aws_lb_listener" "https" {
  count             = var.use_alb ? 1 : 0
  load_balancer_arn = data.aws_lb.alb[0].arn
  port              = 443
}

data "aws_acm_certificate" "realm" {
  count    = var.use_nlb ? 1 : 0
  domain   = "${local.realm_name}.${var.base_domain}"
  statuses = ["ISSUED"]
}

data "aws_route53_zone" "realm" {
  name = "${local.realm_name}.${var.base_domain}"
}
