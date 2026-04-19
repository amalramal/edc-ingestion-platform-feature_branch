# Task Definition
resource "aws_ecs_task_definition" "task" {
  family                   = local.service_realm_name
  network_mode             = var.task_definition.network_mode
  requires_compatibilities = var.task_definition.requires_compatibilities
  cpu                      = var.task_definition.cpu
  memory                   = var.task_definition.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  dynamic "volume" {
    for_each = var.task_definition.efs_volumes == null ? [] : var.task_definition.efs_volumes

    content {
      name = volume.value.name
      efs_volume_configuration {
        file_system_id = volume.value.file_system_id
        root_directory = volume.value.root_directory
      }
    }
  }

  container_definitions = jsonencode(local.container_definition)

  tags = merge(var.tags, {
    Name = local.service_realm_name
  })
}



# ECS Service
resource "aws_ecs_service" "svc" {
  name                   = local.service_realm_name
  cluster                = data.aws_ecs_cluster.realm.id
  task_definition        = aws_ecs_task_definition.task.arn
  desired_count          = var.container_definition.desired_count
  enable_execute_command = var.task_definition.enable_execute_command
  force_new_deployment   = var.task_definition.force_new_deployment

  # Deployment configuration: explicit settings for safe rollouts
  # Keep 100% of tasks healthy during deployment (old tasks stay until new ones are healthy)
  deployment_minimum_healthy_percent = 100
  # Allow up to 200% capacity during deployment (can run 2x tasks temporarily)
  deployment_maximum_percent = 200

  health_check_grace_period_seconds = 60

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = var.task_definition.fargate_spot_capacity
    base              = 0
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = var.task_definition.fargate_capacity
    base              = 0
  }

  network_configuration {
    subnets          = data.aws_subnets.private.ids
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = false
  }

  # ALB target group
  dynamic "load_balancer" {
    for_each = var.use_alb ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.main[0].arn
      container_name   = var.service_name
      container_port   = var.container_definition.web_ui_port
    }
  }

  # NLB target groups (one per listener)
  dynamic "load_balancer" {
    for_each = var.use_nlb ? aws_lb_target_group.nlb : {}
    content {
      target_group_arn = load_balancer.value.arn
      container_name   = var.service_name
      container_port   = load_balancer.value.port
    }
  }

  # Allow external deployments (e.g., from CI/CD)
  deployment_controller {
    type = "ECS"
  }

  # Ignore changes to desired_count for auto-scaling
  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = merge(var.tags, {
    Name = local.service_realm_name
  })
}
