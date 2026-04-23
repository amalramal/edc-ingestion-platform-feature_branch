
resource "aws_iam_policy" "exec_access" {
  name        = "${var.environment}-sftpgo-ecs-exec"
  description = "Allows exec access into ECS container"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = [
          "*"
        ]
      }
    ]
  })
  tags = {
    "service" = "sftpgo"
  }
}


module "sftpgo_ecs" {
  # source = "git::ssh://git@github.com/ledgerrun/terraform-modules.git?ref=ecs-service/v2.0.0"
  source = "git::ssh://git@github.com/ledgerrun/terraform-modules.git//ecs-service?ref=AD-CTMS-14591-single-nat-gateway"


  environment  = var.environment
  service_name = "sftpgo"

  use_alb = false
  use_nlb = true

  nlb_config = {
    listeners = {
      web = {
        protocol    = "TLS"
        port        = 443
        target_port = 8080
      }
      sftp = {
        protocol    = "TCP"
        port        = 2022
        target_port = 2022
        health_check = {
          protocol = "HTTP"
          port     = "8080"
        }
      }
    }
  }

  container_definition = {
    image       = "ghcr.io/drakkan/sftpgo"
    image_tag   = "v2"
    web_ui_port = 8080
    environment_variables = [
      {
        "name" : "SFTPGO_CONFIG_DIR",
        "value" : "/var/lib/sftpgo"
      },
      {
        "name" : "SFTPGO_CONFIG_FILE",
        "value" : "/var/lib/sftpgo/config.json"
      },
      {
        "name" : "SFTPGO_LOG_LEVEL",
        "value" : "warn"

      }
    ]
    mount_points = [
      {
        "sourceVolume" : "sftpgo-efs-config",
        "containerPath" : "/var/lib/sftpgo",
        "readOnly" : false
      }
    ]
    port_mappings = [
      {
        name          = "web",
        containerPort = 8080,
        hostPort      = 8080,
        protocol      = "tcp",
      },
      {
        name          = "sftp",
        containerPort = 2022,
        hostPort      = 2022,
        protocol      = "tcp"
      }
    ]
    user = "root"
  }

  task_definition = {
    attach_execution_iam_policies = [
      "arn:aws:iam::aws:policy/AmazonElasticFileSystemClientReadWriteAccess",
    ]
    attach_task_iam_policies = [
      aws_iam_policy.exec_access.arn,
      aws_iam_policy.sftpgo_s3_access.arn,
    ]
    efs_volumes = [
      {
        name           = "sftpgo-efs-config"
        file_system_id = "fs-${split("fs-", aws_efs_file_system.config.id)[1]}"
        root_directory = "/"
      }
    ]
    enable_execute_command = true
  }
}
