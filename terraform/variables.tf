# =============================================================================
# EDC Ingestion Platform — Terraform Variables
# =============================================================================
# Every variable carries a safe local-dev default so `terraform plan` works
# without a tfvars file.  Production overrides are supplied via CI/CD vars.
#
# Container env is kept in sync with `docker-compose.yml` (service
# `fastapi_trigger`) and `src/edc_ingestion/config.py` unless noted (e.g. compose
# omits LOG_FORMAT / DB pool — Terraform sets sensible ECS defaults).
# =============================================================================

variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "AWS deployment tier (dev | uat | prod). Passed to containers as EDC_ENVIRONMENT when not using LocalStack."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "environment must be one of: dev, uat, prod."
  }
}

variable "localstack_endpoint" {
  description = "LocalStack gateway URL for local development."
  type        = string
  default     = "http://localhost:4566"
}

variable "assume_compose_bootstrapped_s3_sns" {
  description = "When true and using LocalStack, S3 buckets and the SNS topic are expected to exist (docker-compose localstack_init). Terraform then imports them via data sources and applies versioning/encryption only."
  type        = bool
  default     = true
}

variable "localstack_skip_ecs_and_sfn" {
  description = "When true and using LocalStack, skip ECS cluster, task definitions, service, auto-scaling, and Step Functions (LocalStack Community often requires a paid license for ECS). Ignored for real AWS (always provisions ECS/SFN)."
  type        = bool
  default     = true
}

# --- S3 ---

variable "s3_raw_bucket_name" {
  description = "S3 bucket for raw EDC CSV uploads (Raw Layer)."
  type        = string
  default     = "edc-raw-layer"
}

variable "s3_drop_bucket_name" {
  description = "S3 bucket for published artifacts (Drop Site)."
  type        = string
  default     = "edc-drop-site"
}

variable "s3_sftp_landing_prefix" {
  description = "S3 raw-bucket landing prefix: sample/mirror CSVs and ingestion-task Parquet under {prefix}{studyId}/normalized/{runId}/."
  type        = string
  default     = "sftp-landing/"
}

variable "sftpgo_landing_prefix" {
  description = "SFTP/SFTPGo source prefix (home-relative) for inbound CSVs; must match bootstrap + SFTPIngestor."
  type        = string
  default     = "input-files/"
}

variable "s3_partial_api_stash_prefix" {
  description = "S3 key prefix for partial API pull stashes (under raw bucket)."
  type        = string
  default     = "partial-api-pulls/"
}

variable "s3_pipeline_staging_prefix" {
  description = "S3 key prefix for normalized Parquet handoff (under raw bucket)."
  type        = string
  default     = "pipeline-staging/"
}

variable "s3_pipeline_state_prefix" {
  description = "S3 key prefix for Step Functions / pipeline manifest JSON (under raw bucket)."
  type        = string
  default     = "pipeline-state/"
}

# --- Postgres (edc_ingestion.database) ---

variable "database_url" {
  description = "SQLAlchemy database URL for the app (Secrets Manager ARN string not supported here — use full URL)."
  type        = string
  sensitive   = true
  default     = "postgresql://edc_user:edc_pass@localhost:5432/edc_platform"
}

variable "db_pool_size" {
  description = "SQLAlchemy pool size (DB_POOL_SIZE)."
  type        = number
  default     = 5
}

variable "db_max_overflow" {
  description = "SQLAlchemy max overflow connections (DB_MAX_OVERFLOW)."
  type        = number
  default     = 10
}

# --- EDC API / integration (edc_ingestion.config + integration_settings) ---

variable "edc_subject_visit_api_base_url" {
  description = "Subject-visit REST API base URL (empty = SFTP-only / integration from DB)."
  type        = string
  default     = ""
}

variable "edc_oauth2_token_url" {
  description = "OAuth2 token endpoint for subject-visit API."
  type        = string
  default     = ""
}

variable "edc_oauth2_client_id" {
  description = "OAuth2 client id."
  type        = string
  default     = ""
}

variable "edc_oauth2_client_secret" {
  description = "OAuth2 client secret."
  type        = string
  sensitive   = true
  default     = ""
}

variable "edc_subject_visit_page_size" {
  description = "Subject-visit API page size (EDC_SUBJECT_VISIT_PAGE_SIZE). Many APIs max out around 500–1000."
  type        = number
  default     = 500
}

variable "edc_api_timeout_seconds" {
  description = "HTTP timeout for subject-visit API calls (EDC_API_TIMEOUT_SECONDS)."
  type        = number
  default     = 300
}

variable "edc_oauth2_timeout_seconds" {
  description = "HTTP timeout for OAuth2 token request (EDC_OAUTH2_TIMEOUT_SECONDS)."
  type        = number
  default     = 120
}

variable "edc_circuit_failure_threshold" {
  description = "Circuit breaker failure threshold (EDC_CIRCUIT_FAILURE_THRESHOLD)."
  type        = number
  default     = 5
}

variable "edc_circuit_recovery_seconds" {
  description = "Circuit breaker recovery timeout in seconds (EDC_CIRCUIT_RECOVERY_SECONDS)."
  type        = number
  default     = 60
}

variable "edc_subject_visit_source_mode" {
  description = "API_FIRST (API visits + SFTP non-visit CSVs, else full SFTP) | SFTP_ONLY | API_ONLY (EDC_SUBJECT_VISIT_SOURCE_MODE)."
  type        = string
  default     = "SFTP_ONLY"
}

variable "edc_pipeline_depth" {
  description = "RAW | STAGE | PUBLISH — bundled worker/API depth (EDC_PIPELINE_DEPTH). Step Functions split runs ignore this for phase-specific tasks."
  type        = string
  default     = "PUBLISH"
}

variable "edc_milestone_api_base_url" {
  description = "Milestone / FSFV API base URL (EDC_MILESTONE_API_BASE_URL)."
  type        = string
  default     = ""
}

variable "edc_milestone_detail_id" {
  description = "Milestone detail id (EDC_MILESTONE_DETAIL_ID)."
  type        = number
  default     = 14
}

variable "default_sponsor_id" {
  description = "Default tenant when SPONSOR_ID omitted (DEFAULT_SPONSOR_ID)."
  type        = string
  default     = "demo"
}

variable "alert_recipients" {
  description = "Comma-separated alert recipients for in-app alerts (ALERT_RECIPIENTS); may also be set per sponsor in DB."
  type        = string
  default     = ""
}

variable "aws_endpoint_url" {
  description = "Optional S3/SDK endpoint (LocalStack). Leave empty for real AWS."
  type        = string
  default     = ""
}

variable "log_format" {
  description = "edc_ingestion logging: json | console (LOG_FORMAT)."
  type        = string
  default     = "json"
}

variable "log_level" {
  description = "Root log level (LOG_LEVEL)."
  type        = string
  default     = "INFO"
}

# --- docker-compose.yml parity (fastapi_trigger) ---

variable "dask_logging_distributed" {
  description = "Modin/Dask distributed log level (DASK_LOGGING__DISTRIBUTED)."
  type        = string
  default     = "WARNING"
}

variable "aws_access_key_id" {
  description = "Optional static AWS access key (e.g. LocalStack `test`). Empty = omit; use IAM on real ECS."
  type        = string
  default     = ""
}

variable "aws_secret_access_key" {
  description = "Optional static AWS secret key (e.g. LocalStack `test`). Empty = omit."
  type        = string
  sensitive   = true
  default     = ""
}

# --- SNS ---

variable "sns_alert_topic_name" {
  description = "SNS topic for pipeline failure / immutability-violation alerts."
  type        = string
  default     = "edc-pipeline-alerts"
}

# --- Alert Notifications (SNS → Lambda → SES) ---

variable "alert_sender_email" {
  description = "Verified SES email address used as the From address for alert emails."
  type        = string
  default     = "edc-alerts@example.com"
}

variable "alert_recipient_emails" {
  description = "List of email addresses that receive pipeline failure alerts."
  type        = list(string)
  default     = ["ops-team@example.com"]
}

# --- ECS ---

variable "ecs_cluster_name" {
  description = "Name of the ECS Fargate cluster."
  type        = string
  default     = "edc-ingestion-cluster"
}

variable "ecs_fargate_subnet_ids" {
  description = <<-EOT
    Subnet IDs for ECS awsvpc networking and Step Functions ecs:runTask.sync.
    LocalStack: use placeholder-style IDs (see terraform/local.tfvars.example).
    Real AWS: set to your VPC private or public subnets.
  EOT
  type        = list(string)
  default     = ["subnet-00000000000000001"]
}

variable "ecs_task_cpu" {
  description = "CPU units for ECS task definitions (1024 = 1 vCPU)."
  type        = string
  default     = "512"
}

variable "ecs_task_memory" {
  description = "Memory (MiB) for ECS task definitions."
  type        = string
  default     = "1024"
}

variable "worker_image" {
  description = "Container image URI for the worker (Task 1)."
  type        = string
  default     = "edc-ingestion-platform:latest"
}

variable "publisher_image" {
  description = "Container image URI for the publisher (Task 2)."
  type        = string
  default     = "edc-ingestion-platform:latest"
}

variable "api_image" {
  description = "Container image URI for the FastAPI API service."
  type        = string
  default     = "edc-ingestion-platform:latest"
}

# --- ECS Service Auto-Scaling ---

variable "api_desired_count" {
  description = "Desired number of API service tasks at steady state."
  type        = number
  default     = 2
}

variable "api_min_count" {
  description = "Minimum number of API service tasks (scale-in floor)."
  type        = number
  default     = 1
}

variable "api_max_count" {
  description = "Maximum number of API service tasks (scale-out ceiling)."
  type        = number
  default     = 10
}

variable "api_cpu_target" {
  description = "Target average CPU utilisation (%) for API auto-scaling."
  type        = number
  default     = 60
}

variable "api_memory_target" {
  description = "Target average memory utilisation (%) for API auto-scaling."
  type        = number
  default     = 70
}

variable "api_scale_in_cooldown" {
  description = "Cooldown (seconds) after a scale-in before another can occur."
  type        = number
  default     = 300
}

variable "api_scale_out_cooldown" {
  description = "Cooldown (seconds) after a scale-out before another can occur."
  type        = number
  default     = 60
}
