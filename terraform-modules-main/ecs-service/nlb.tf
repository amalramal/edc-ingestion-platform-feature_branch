# NLB Security Group
resource "aws_security_group" "nlb" {
  count       = var.use_nlb ? 1 : 0
  name        = "${local.service_realm_name}-nlb-sg"
  description = "Security group for ${local.service_realm_name} NLB"
  vpc_id      = data.aws_vpc.vpc.id

  dynamic "ingress" {
    for_each = var.nlb_config.listeners
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Inbound ${ingress.key} - ${ingress.value.protocol}/${ingress.value.port}"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound"
  }

  tags = merge(var.tags, {
    Name = "${local.service_realm_name}-nlb-sg"
  })
}

# Network Load Balancer
resource "aws_lb" "nlb" {
  count              = var.use_nlb ? 1 : 0
  name               = "${local.service_realm_name}-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = data.aws_subnets.public.ids
  security_groups    = [aws_security_group.nlb[0].id]

  tags = merge(var.tags, {
    Name = "${local.service_realm_name}-nlb"
  })
}

# NLB Target Groups — one per listener
resource "aws_lb_target_group" "nlb" {
  for_each = local.nlb_listeners

  name               = "${local.service_realm_name}-${each.key}"
  port               = each.value.target_port
  protocol           = "TCP"
  vpc_id             = data.aws_vpc.vpc.id
  target_type        = "ip"
  preserve_client_ip = each.value.preserve_client_ip

  deregistration_delay = 30

  dynamic "health_check" {
    for_each = each.value.health_check != null ? [each.value.health_check] : []
    content {
      enabled             = health_check.value.enabled
      healthy_threshold   = health_check.value.healthy_threshold
      interval            = health_check.value.interval
      matcher             = health_check.value.matcher
      path                = health_check.value.path
      protocol            = health_check.value.protocol
      port                = health_check.value.port
      unhealthy_threshold = health_check.value.unhealthy_threshold
    }
  }

  tags = merge(var.tags, {
    Name = "${local.service_realm_name}-${each.key}-tg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# TLS Listeners — terminated with realm certificate
resource "aws_lb_listener" "nlb_tls" {
  for_each = local.nlb_tls_listeners

  load_balancer_arn = aws_lb.nlb[0].arn
  port              = each.value.port
  protocol          = "TLS"
  certificate_arn   = data.aws_acm_certificate.realm[0].arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb[each.key].arn
  }

  tags = merge(var.tags, {
    Name = "${local.service_realm_name}-${each.key}-listener"
  })
}

# TCP Listeners — plain TCP passthrough
resource "aws_lb_listener" "nlb_tcp" {
  for_each = local.nlb_tcp_listeners

  load_balancer_arn = aws_lb.nlb[0].arn
  port              = each.value.port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb[each.key].arn
  }

  tags = merge(var.tags, {
    Name = "${local.service_realm_name}-${each.key}-listener"
  })
}
