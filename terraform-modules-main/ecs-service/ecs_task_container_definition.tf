locals {
  container_definition = [
    merge(
      {
        name      = var.service_name
        image     = "${var.container_definition.image}:${var.container_definition.image_tag}"
        essential = var.container_definition.essential
        portMappings = [{
          name          = "web-ui"
          containerPort = var.container_definition.web_ui_port
          hostPort      = var.container_definition.web_ui_port
          protocol      = "tcp"
        }]
      },
      var.container_definition.port_mappings == null ? {} : {
        portMappings = [
          for pm in var.container_definition.port_mappings : merge(
            {
              name          = pm.name
              containerPort = pm.containerPort
              hostPort      = pm.hostPort
              protocol      = pm.protocol
            }
          )
        ]
      },
      var.container_definition.command == null ? {} : { command = var.container_definition.command },
      var.container_definition.environment_variables == null ? {} : { environment = var.container_definition.environment_variables },
      var.container_definition.mount_points == null ? {} : { mountPoints = var.container_definition.mount_points },
      var.container_definition.user == null ? {} : { user = var.container_definition.user },
      var.container_definition.logdriver == "awslogs" ? {
        logConfiguration = {
          "logDriver" = "awslogs",
          "options" = {
            "awslogs-create-group"  = "true",
            "awslogs-stream-prefix" = "ecs",
            "awslogs-group"         = "/ecs/${local.service_realm_name}",
            "awslogs-region"        = data.aws_region.current.region,
          }
        }
      } : {},
      length(var.secrets_manager_secrets) < 0 ? {} : {
        secrets = [
          for secret in var.secrets_manager_secrets : {
            name      = secret,
            valueFrom = "${aws_secretsmanager_secret.service[0].arn}:${secret}::"
          }
        ]
      }
    )
  ]
}
