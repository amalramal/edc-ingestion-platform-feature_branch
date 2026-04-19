# Security Group for ECS Tasks
resource "aws_security_group" "tasks" {
  name        = "${local.service_realm_name}-tasks-sg"
  description = "Security group for ${local.service_realm_name} ECS tasks"
  vpc_id      = data.aws_vpc.vpc.id

  # Allow inbound from ALB (only when using ALB)
  dynamic "ingress" {
    for_each = var.use_alb ? [1] : []
    content {
      from_port       = var.container_definition.web_ui_port
      to_port         = var.container_definition.web_ui_port
      protocol        = "tcp"
      security_groups = data.aws_lb.alb[0].security_groups
      description     = "From ALB"
    }
  }

  # Allow inbound from NLB security group for each listener target port
  dynamic "ingress" {
    for_each = var.use_nlb ? var.nlb_config.listeners : {}
    content {
      from_port       = ingress.value.target_port
      to_port         = ingress.value.target_port
      protocol        = "tcp"
      security_groups = [aws_security_group.nlb[0].id]
      description     = "From NLB - ${ingress.key}"
    }
  }

  dynamic "ingress" {
    for_each = var.task_definition.sg_ingress == null ? [] : var.task_definition.sg_ingress
    content {
      from_port       = ingress.value.from_port
      to_port         = ingress.value.to_port
      protocol        = ingress.value.protocol
      security_groups = ingress.value.security_groups
      cidr_blocks     = ingress.value.cidr_blocks
      description     = ingress.value.description
    }
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound"
  }

  tags = merge(var.tags, {
    Name = "${local.service_realm_name}-tasks-sg"
  })
}
