# =============================================================================
# EDC Ingestion Platform — Core Infrastructure
# =============================================================================
# Resources provisioned:
#   1. Two S3 buckets (Raw Layer + Drop Site) with encryption and versioning.
#   2. One SNS topic for pipeline alerts.
#   3. SNS → Lambda → SES alert notification chain.
#   4. ECS Cluster + three Fargate Task Definitions (Worker, Publisher, API) with
#      container env aligned to src/edc_ingestion/config.py + docker-compose.yml
#      (see variables.tf, locals.edc_container_env).
#   5. ECS Service for API with Application Auto Scaling (CPU + Memory).
#   6. IAM execution roles for ECS tasks.
#   7. Step Functions State Machine orchestrating the 2-step pipeline.
#   8. CloudWatch Log Groups for ECS tasks, API, and Lambda.
# =============================================================================

# ---------------------------------------------------------------------------
# S3 / SNS — Terraform vs docker-compose localstack_init (LocalStack)
# ---------------------------------------------------------------------------

locals {
  use_tf_created_s3_sns = !local.is_local || !var.assume_compose_bootstrapped_s3_sns
  provision_ecs_sfn     = !local.is_local || !var.localstack_skip_ecs_and_sfn
}

resource "aws_s3_bucket" "raw_layer" {
  count         = local.use_tf_created_s3_sns ? 1 : 0
  bucket        = var.s3_raw_bucket_name
  force_destroy = true
}

data "aws_s3_bucket" "raw_layer_existing" {
  count  = local.use_tf_created_s3_sns ? 0 : 1
  bucket = var.s3_raw_bucket_name
}

locals {
  raw_layer_bucket_id  = local.use_tf_created_s3_sns ? aws_s3_bucket.raw_layer[0].id : data.aws_s3_bucket.raw_layer_existing[0].id
  raw_layer_bucket_arn = local.use_tf_created_s3_sns ? aws_s3_bucket.raw_layer[0].arn : data.aws_s3_bucket.raw_layer_existing[0].arn
}

resource "aws_s3_bucket_versioning" "raw_layer" {
  bucket = local.raw_layer_bucket_id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "raw_layer" {
  bucket = local.raw_layer_bucket_id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "raw_layer" {
  bucket                  = local.raw_layer_bucket_id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "drop_site" {
  count         = local.use_tf_created_s3_sns ? 1 : 0
  bucket        = var.s3_drop_bucket_name
  force_destroy = true
}

data "aws_s3_bucket" "drop_site_existing" {
  count  = local.use_tf_created_s3_sns ? 0 : 1
  bucket = var.s3_drop_bucket_name
}

locals {
  drop_site_bucket_id  = local.use_tf_created_s3_sns ? aws_s3_bucket.drop_site[0].id : data.aws_s3_bucket.drop_site_existing[0].id
  drop_site_bucket_arn = local.use_tf_created_s3_sns ? aws_s3_bucket.drop_site[0].arn : data.aws_s3_bucket.drop_site_existing[0].arn
}

resource "aws_s3_bucket_versioning" "drop_site" {
  bucket = local.drop_site_bucket_id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "drop_site" {
  bucket = local.drop_site_bucket_id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "drop_site" {
  bucket                  = local.drop_site_bucket_id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# SNS — Pipeline Alerts
# ---------------------------------------------------------------------------

resource "aws_sns_topic" "pipeline_alerts" {
  count = local.use_tf_created_s3_sns ? 1 : 0
  name  = var.sns_alert_topic_name
}

data "aws_sns_topic" "pipeline_alerts_existing" {
  count = local.use_tf_created_s3_sns ? 0 : 1
  name  = var.sns_alert_topic_name
}

locals {
  pipeline_alerts_topic_arn = local.use_tf_created_s3_sns ? aws_sns_topic.pipeline_alerts[0].arn : data.aws_sns_topic.pipeline_alerts_existing[0].arn
}

# ---------------------------------------------------------------------------
# Container environment — src/edc_ingestion/config.py + database.py + docker-compose
#   (service `fastapi_trigger`: S3/SNS/EDC env; optional LocalStack endpoint + keys).
# ---------------------------------------------------------------------------

locals {
  edc_container_env = concat(
    [
      { name = "AWS_DEFAULT_REGION", value = var.aws_region },
      { name = "DATABASE_URL", value = var.database_url },
      { name = "DB_POOL_SIZE", value = tostring(var.db_pool_size) },
      { name = "DB_MAX_OVERFLOW", value = tostring(var.db_max_overflow) },
      { name = "S3_RAW_BUCKET", value = var.s3_raw_bucket_name },
      { name = "S3_DROP_BUCKET", value = var.s3_drop_bucket_name },
      { name = "S3_SFTP_LANDING_PREFIX", value = var.s3_sftp_landing_prefix },
      { name = "SFTPGO_LANDING_PREFIX", value = var.sftpgo_landing_prefix },
      { name = "S3_PARTIAL_API_STASH_PREFIX", value = var.s3_partial_api_stash_prefix },
      { name = "S3_PIPELINE_STAGING_PREFIX", value = var.s3_pipeline_staging_prefix },
      { name = "S3_PIPELINE_STATE_PREFIX", value = var.s3_pipeline_state_prefix },
      { name = "SNS_ALERT_TOPIC_ARN", value = local.pipeline_alerts_topic_arn },
      { name = "DEFAULT_SPONSOR_ID", value = var.default_sponsor_id },
      { name = "ALERT_RECIPIENTS", value = var.alert_recipients },
      { name = "EDC_SUBJECT_VISIT_API_BASE_URL", value = var.edc_subject_visit_api_base_url },
      { name = "EDC_OAUTH2_TOKEN_URL", value = var.edc_oauth2_token_url },
      { name = "EDC_OAUTH2_CLIENT_ID", value = var.edc_oauth2_client_id },
      { name = "EDC_OAUTH2_CLIENT_SECRET", value = var.edc_oauth2_client_secret },
      { name = "EDC_SUBJECT_VISIT_PAGE_SIZE", value = tostring(var.edc_subject_visit_page_size) },
      { name = "EDC_API_TIMEOUT_SECONDS", value = tostring(var.edc_api_timeout_seconds) },
      { name = "EDC_OAUTH2_TIMEOUT_SECONDS", value = tostring(var.edc_oauth2_timeout_seconds) },
      { name = "EDC_CIRCUIT_FAILURE_THRESHOLD", value = tostring(var.edc_circuit_failure_threshold) },
      { name = "EDC_CIRCUIT_RECOVERY_SECONDS", value = tostring(var.edc_circuit_recovery_seconds) },
      { name = "EDC_SUBJECT_VISIT_SOURCE_MODE", value = var.edc_subject_visit_source_mode },
      { name = "EDC_PIPELINE_DEPTH", value = var.edc_pipeline_depth },
      { name = "EDC_MILESTONE_API_BASE_URL", value = var.edc_milestone_api_base_url },
      { name = "EDC_MILESTONE_DETAIL_ID", value = tostring(var.edc_milestone_detail_id) },
      { name = "DASK_LOGGING__DISTRIBUTED", value = var.dask_logging_distributed },
      { name = "LOG_FORMAT", value = var.log_format },
      { name = "LOG_LEVEL", value = var.log_level },
      # Aligns with src/edc_ingestion/config.py (LocalStack TF → local-localstack; real AWS → dev|uat|prod).
      { name = "EDC_ENVIRONMENT", value = local.is_local ? "local-localstack" : var.environment },
      # Worker/publisher tasks always run pipeline steps in-container (avoid SFN recursion).
      { name = "LOCAL_RUNTIME_MODE", value = "compose" },
    ],
    var.aws_endpoint_url != "" ? [{ name = "AWS_ENDPOINT_URL", value = var.aws_endpoint_url }] : [],
    var.aws_access_key_id != "" ? [{ name = "AWS_ACCESS_KEY_ID", value = var.aws_access_key_id }] : [],
    var.aws_secret_access_key != "" ? [{ name = "AWS_SECRET_ACCESS_KEY", value = var.aws_secret_access_key }] : [],
  )
}

# ---------------------------------------------------------------------------
# SES — Email Identities
# ---------------------------------------------------------------------------

resource "aws_ses_email_identity" "sender" {
  email = var.alert_sender_email
}

resource "aws_ses_email_identity" "recipients" {
  for_each = toset(var.alert_recipient_emails)
  email    = each.value
}

# ---------------------------------------------------------------------------
# Lambda — SNS → SES Alert Emailer
# ---------------------------------------------------------------------------

data "archive_file" "alert_emailer" {
  type        = "zip"
  source_file = "${path.module}/lambda/alert_emailer.py"
  output_path = "${path.module}/lambda/alert_emailer.zip"
}

resource "aws_cloudwatch_log_group" "alert_lambda" {
  name              = "/aws/lambda/edc-alert-emailer"
  retention_in_days = 30
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "alert_lambda" {
  name               = "edc-alert-emailer-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "alert_lambda_permissions" {
  statement {
    effect    = "Allow"
    actions   = ["ses:SendEmail", "ses:SendRawEmail"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.alert_lambda.arn}:*"]
  }
}

resource "aws_iam_role_policy" "alert_lambda" {
  name   = "edc-alert-emailer-permissions"
  role   = aws_iam_role.alert_lambda.id
  policy = data.aws_iam_policy_document.alert_lambda_permissions.json
}

resource "aws_lambda_function" "alert_emailer" {
  function_name    = "edc-alert-emailer"
  role             = aws_iam_role.alert_lambda.arn
  handler          = "alert_emailer.handler"
  runtime          = "python3.13"
  timeout          = 30
  memory_size      = 128
  filename         = data.archive_file.alert_emailer.output_path
  source_code_hash = data.archive_file.alert_emailer.output_base64sha256

  environment {
    variables = {
      SENDER_EMAIL     = var.alert_sender_email
      RECIPIENT_EMAILS = join(",", var.alert_recipient_emails)
    }
  }

  depends_on = [aws_cloudwatch_log_group.alert_lambda]
}

# ---------------------------------------------------------------------------
# SNS → Lambda Subscription
# ---------------------------------------------------------------------------

resource "aws_sns_topic_subscription" "alert_to_lambda" {
  topic_arn = local.pipeline_alerts_topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.alert_emailer.arn
}

resource "aws_lambda_permission" "sns_invoke" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alert_emailer.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = local.pipeline_alerts_topic_arn
}

# ---------------------------------------------------------------------------
# CloudWatch Log Groups (ECS tasks only)
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "worker" {
  count             = local.provision_ecs_sfn ? 1 : 0
  name              = "/ecs/edc-worker"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "publisher" {
  count             = local.provision_ecs_sfn ? 1 : 0
  name              = "/ecs/edc-publisher"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "api" {
  count             = local.provision_ecs_sfn ? 1 : 0
  name              = "/ecs/edc-api"
  retention_in_days = 30
}

# ---------------------------------------------------------------------------
# IAM — ECS Task Execution Role
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  count              = local.provision_ecs_sfn ? 1 : 0
  name               = "edc-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  count      = local.provision_ecs_sfn ? 1 : 0
  role       = aws_iam_role.ecs_task_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_task_permissions" {
  count = local.provision_ecs_sfn ? 1 : 0
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
    ]
    resources = [
      local.raw_layer_bucket_arn,
      "${local.raw_layer_bucket_arn}/*",
      local.drop_site_bucket_arn,
      "${local.drop_site_bucket_arn}/*",
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [local.pipeline_alerts_topic_arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "${aws_cloudwatch_log_group.worker[0].arn}:*",
      "${aws_cloudwatch_log_group.publisher[0].arn}:*",
      "${aws_cloudwatch_log_group.api[0].arn}:*",
    ]
  }
}

resource "aws_iam_role" "ecs_task_role" {
  count              = local.provision_ecs_sfn ? 1 : 0
  name               = "edc-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

resource "aws_iam_role_policy" "ecs_task_inline" {
  count  = local.provision_ecs_sfn ? 1 : 0
  name   = "edc-task-permissions"
  role   = aws_iam_role.ecs_task_role[0].id
  policy = data.aws_iam_policy_document.ecs_task_permissions[0].json
}

# ---------------------------------------------------------------------------
# ECS Cluster
# ---------------------------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  count = local.provision_ecs_sfn ? 1 : 0
  name  = var.ecs_cluster_name
}

# ---------------------------------------------------------------------------
# ECS Task Definition — Worker (Task 1: Ingestion & Validation)
# ---------------------------------------------------------------------------

resource "aws_ecs_task_definition" "worker" {
  count                    = local.provision_ecs_sfn ? 1 : 0
  family                   = "edc-worker"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution[0].arn
  task_role_arn            = aws_iam_role.ecs_task_role[0].arn

  container_definitions = jsonencode([
    {
      name      = "edc-worker"
      image     = var.worker_image
      essential = true
      command   = ["python", "-m", "edc_ingestion.worker"]

      environment = local.edc_container_env

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.worker[0].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "worker"
        }
      }
    }
  ])
}

# ---------------------------------------------------------------------------
# ECS Task Definition — Publisher (Task 2: Artifact Publishing)
# ---------------------------------------------------------------------------

resource "aws_ecs_task_definition" "publisher" {
  count                    = local.provision_ecs_sfn ? 1 : 0
  family                   = "edc-publisher"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution[0].arn
  task_role_arn            = aws_iam_role.ecs_task_role[0].arn

  container_definitions = jsonencode([
    {
      name      = "edc-publisher"
      image     = var.publisher_image
      essential = true
      command   = ["python", "-m", "edc_ingestion.publisher"]

      environment = local.edc_container_env

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.publisher[0].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "publisher"
        }
      }
    }
  ])
}

# ---------------------------------------------------------------------------
# ECS Task Definition — API Service (FastAPI)
# ---------------------------------------------------------------------------

resource "aws_ecs_task_definition" "api" {
  count                    = local.provision_ecs_sfn ? 1 : 0
  family                   = "edc-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution[0].arn
  task_role_arn            = aws_iam_role.ecs_task_role[0].arn

  container_definitions = jsonencode([
    {
      name      = "edc-api"
      image     = var.api_image
      essential = true
      command   = ["uvicorn", "edc_ingestion.app:app", "--host", "0.0.0.0", "--port", "8000"]

      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]

      environment = local.edc_container_env

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api[0].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "api"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "python -c \"import urllib.request; urllib.request.urlopen('http://localhost:8000/health')\""]
        interval    = 15
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }
    }
  ])
}

# ---------------------------------------------------------------------------
# ECS Service — API (always-on, auto-scaled)
# ---------------------------------------------------------------------------

resource "aws_ecs_service" "api" {
  count           = local.provision_ecs_sfn ? 1 : 0
  name            = "edc-api-service"
  cluster         = aws_ecs_cluster.main[0].id
  task_definition = aws_ecs_task_definition.api[0].arn
  desired_count   = var.api_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.ecs_fargate_subnet_ids
    assign_public_ip = true
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  lifecycle {
    ignore_changes = [desired_count]
  }
}

# ---------------------------------------------------------------------------
# Application Auto Scaling — API Service
# ---------------------------------------------------------------------------

resource "aws_appautoscaling_target" "api" {
  count              = local.provision_ecs_sfn ? 1 : 0
  max_capacity       = var.api_max_count
  min_capacity       = var.api_min_count
  resource_id        = "service/${aws_ecs_cluster.main[0].name}/${aws_ecs_service.api[0].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "api_cpu" {
  count              = local.provision_ecs_sfn ? 1 : 0
  name               = "edc-api-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api[0].resource_id
  scalable_dimension = aws_appautoscaling_target.api[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.api[0].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.api_cpu_target
    scale_in_cooldown  = var.api_scale_in_cooldown
    scale_out_cooldown = var.api_scale_out_cooldown

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_appautoscaling_policy" "api_memory" {
  count              = local.provision_ecs_sfn ? 1 : 0
  name               = "edc-api-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api[0].resource_id
  scalable_dimension = aws_appautoscaling_target.api[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.api[0].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.api_memory_target
    scale_in_cooldown  = var.api_scale_in_cooldown
    scale_out_cooldown = var.api_scale_out_cooldown

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}

# ---------------------------------------------------------------------------
# IAM — Step Functions Execution Role
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "sfn_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "sfn_execution" {
  count              = local.provision_ecs_sfn ? 1 : 0
  name               = "edc-sfn-execution-role"
  assume_role_policy = data.aws_iam_policy_document.sfn_assume_role.json
}

data "aws_iam_policy_document" "sfn_permissions" {
  count = local.provision_ecs_sfn ? 1 : 0
  statement {
    effect = "Allow"
    actions = [
      "ecs:RunTask",
      "ecs:StopTask",
      "ecs:DescribeTasks",
    ]
    resources = ["*"]
  }

  statement {
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      aws_iam_role.ecs_task_execution[0].arn,
      aws_iam_role.ecs_task_role[0].arn,
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [local.pipeline_alerts_topic_arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "events:PutTargets",
      "events:PutRule",
      "events:DescribeRule",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "sfn_inline" {
  count  = local.provision_ecs_sfn ? 1 : 0
  name   = "edc-sfn-permissions"
  role   = aws_iam_role.sfn_execution[0].id
  policy = data.aws_iam_policy_document.sfn_permissions[0].json
}

# ---------------------------------------------------------------------------
# Step Functions State Machine — 2-Step EDC Pipeline
# ---------------------------------------------------------------------------

resource "aws_sfn_state_machine" "edc_pipeline" {
  count    = local.provision_ecs_sfn ? 1 : 0
  name     = "edc-ingestion-pipeline"
  role_arn = aws_iam_role.sfn_execution[0].arn

  definition = jsonencode({
    Comment = "EDC Ingestion Pipeline — Ingestion → Validation → Publisher (3 ECS tasks)"
    StartAt = "RunIngestion"
    States = {
      RunIngestion = {
        Type     = "Task"
        Resource = "arn:aws:states:::ecs:runTask.sync"
        Parameters = {
          LaunchType     = "FARGATE"
          Cluster        = aws_ecs_cluster.main[0].arn
          TaskDefinition = aws_ecs_task_definition.worker[0].arn
          Overrides = {
            ContainerOverrides = [
              {
                Name = "edc-worker"
                Environment = [
                  { "Name" = "PIPELINE_PHASE", "Value" = "ingestion" },
                  { "Name" = "STUDY_ID", "Value.$" = "$.study_id" },
                  { "Name" = "SPONSOR_ID", "Value.$" = "$.sponsor_id" },
                  { "Name" = "SFN_EXECUTION_NAME", "Value.$" = "$$$$.Execution.Name" },
                ]
              }
            ]
          }
          NetworkConfiguration = {
            AwsvpcConfiguration = {
              Subnets        = var.ecs_fargate_subnet_ids
              AssignPublicIp = "ENABLED"
            }
          }
        }
        ResultPath = "$.ingestionResult"
        Next       = "RunValidation"
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.error"
            Next        = "NotifyFailure"
          }
        ]
      }

      RunValidation = {
        Type     = "Task"
        Resource = "arn:aws:states:::ecs:runTask.sync"
        Parameters = {
          LaunchType     = "FARGATE"
          Cluster        = aws_ecs_cluster.main[0].arn
          TaskDefinition = aws_ecs_task_definition.worker[0].arn
          Overrides = {
            ContainerOverrides = [
              {
                Name = "edc-worker"
                Environment = [
                  { "Name" = "PIPELINE_PHASE", "Value" = "validation" },
                  { "Name" = "STUDY_ID", "Value.$" = "$.study_id" },
                  { "Name" = "SPONSOR_ID", "Value.$" = "$.sponsor_id" },
                  { "Name" = "SFN_EXECUTION_NAME", "Value.$" = "$$$$.Execution.Name" },
                ]
              }
            ]
          }
          NetworkConfiguration = {
            AwsvpcConfiguration = {
              Subnets        = var.ecs_fargate_subnet_ids
              AssignPublicIp = "ENABLED"
            }
          }
        }
        ResultPath = "$.validationResult"
        Next       = "RunPublisher"
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.error"
            Next        = "NotifyFailure"
          }
        ]
      }

      RunPublisher = {
        Type     = "Task"
        Resource = "arn:aws:states:::ecs:runTask.sync"
        Parameters = {
          LaunchType     = "FARGATE"
          Cluster        = aws_ecs_cluster.main[0].arn
          TaskDefinition = aws_ecs_task_definition.publisher[0].arn
          Overrides = {
            ContainerOverrides = [
              {
                Name = "edc-publisher"
                Environment = [
                  { "Name" = "STUDY_ID", "Value.$" = "$.study_id" },
                  { "Name" = "SPONSOR_ID", "Value.$" = "$.sponsor_id" },
                  { "Name" = "SFN_EXECUTION_NAME", "Value.$" = "$$$$.Execution.Name" },
                ]
              }
            ]
          }
          NetworkConfiguration = {
            AwsvpcConfiguration = {
              Subnets        = var.ecs_fargate_subnet_ids
              AssignPublicIp = "ENABLED"
            }
          }
        }
        ResultPath = "$.publisherResult"
        Next       = "PipelineSucceeded"
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.error"
            Next        = "NotifyFailure"
          }
        ]
      }

      NotifyFailure = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn    = local.pipeline_alerts_topic_arn
          Subject     = "EDC Pipeline FAILED"
          "Message.$" = "States.Format('Pipeline failed for sponsor {}. Error: {}', $.sponsor_id, States.JsonToString($.error))"
        }
        Next = "PipelineFailed"
      }

      PipelineFailed = {
        Type  = "Fail"
        Error = "PipelineExecutionFailed"
        Cause = "One or more pipeline tasks failed. See SNS alert for details."
      }

      PipelineSucceeded = {
        Type = "Succeed"
      }
    }
  })
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

output "raw_bucket_arn" {
  description = "ARN of the Raw Layer S3 bucket."
  value       = local.raw_layer_bucket_arn
}

output "drop_bucket_arn" {
  description = "ARN of the Drop Site S3 bucket."
  value       = local.drop_site_bucket_arn
}

output "sns_topic_arn" {
  description = "ARN of the pipeline alerts SNS topic."
  value       = local.pipeline_alerts_topic_arn
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster (empty when localstack_skip_ecs_and_sfn is true on LocalStack)."
  value       = try(aws_ecs_cluster.main[0].arn, "")
}

output "state_machine_arn" {
  description = "ARN of the Step Functions state machine (empty when ECS/SFN skipped on LocalStack)."
  value       = try(aws_sfn_state_machine.edc_pipeline[0].arn, "")
}

output "alert_lambda_arn" {
  description = "ARN of the alert emailer Lambda function."
  value       = aws_lambda_function.alert_emailer.arn
}

output "api_service_name" {
  description = "Name of the API ECS service (empty when ECS skipped on LocalStack)."
  value       = try(aws_ecs_service.api[0].name, "")
}

output "api_scaling_range" {
  description = "API auto-scaling range (min–max tasks)."
  value       = "${var.api_min_count}–${var.api_max_count}"
}
