resource "aws_lb_target_group" "main" {
  count       = var.use_alb ? 1 : 0
  name        = "${local.service_realm_name}-tg"
  port        = var.container_definition.web_ui_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.vpc.id
  target_type = "ip"

  tags = merge(var.tags, {
    Name = "${local.service_realm_name}-tg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener_rule" "main" {
  count        = var.use_alb ? 1 : 0
  listener_arn = data.aws_lb_listener.https[0].arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main[0].arn
  }

  condition {
    host_header {
      values = ["${var.service_name}.${local.realm_name}.${var.base_domain}"]
    }
  }

  tags = merge(var.tags, {
    Name = "${local.service_realm_name}-rule"
  })
}
