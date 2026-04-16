# =============================================================================
# EDC Ingestion Platform — Terraform Provider Configuration
# =============================================================================
# Dual-mode provider setup:
#   LOCAL  — localstack_endpoint = "http://localhost:4566" (default)
#            Uses static test credentials and skip_* flags.
#   AWS    — localstack_endpoint = ""  (set in aws.tfvars)
#            Uses real AWS credentials from the environment / CLI profile.
#
# The `locals.is_local` flag drives conditional behaviour throughout.
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  is_local = var.localstack_endpoint != ""
}

# ---------------------------------------------------------------------------
# Provider: LocalStack (local development)
# ---------------------------------------------------------------------------
provider "aws" {
  alias  = "localstack"
  region = var.aws_region

  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  # LocalStack S3 expects path-style; virtual-hosted requests hit HEAD / and hang/fail.
  s3_use_path_style = true

  endpoints {
    s3             = var.localstack_endpoint
    sns            = var.localstack_endpoint
    ses            = var.localstack_endpoint
    lambda         = var.localstack_endpoint
    ecs            = var.localstack_endpoint
    iam            = var.localstack_endpoint
    stepfunctions  = var.localstack_endpoint
    cloudwatchlogs = var.localstack_endpoint
    appautoscaling = var.localstack_endpoint
  }

  default_tags {
    tags = {
      Project     = "edc-ingestion-platform"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# ---------------------------------------------------------------------------
# Provider: Real AWS
# ---------------------------------------------------------------------------
provider "aws" {
  alias  = "cloud"
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "edc-ingestion-platform"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# ---------------------------------------------------------------------------
# Default (un-aliased) provider — routes to local or cloud based on config.
# Terraform does not support conditional provider selection natively, so we
# use the LocalStack provider as the default when localstack_endpoint is set.
# For AWS deployments, set localstack_endpoint = "" and Terraform will still
# route through the localstack-aliased provider but with empty endpoints,
# which the AWS provider treats as standard AWS API endpoints.
# ---------------------------------------------------------------------------
provider "aws" {
  region = var.aws_region

  access_key                  = local.is_local ? "test" : null
  secret_key                  = local.is_local ? "test" : null
  skip_credentials_validation = local.is_local
  skip_metadata_api_check     = local.is_local
  skip_requesting_account_id  = local.is_local
  s3_use_path_style           = local.is_local

  dynamic "endpoints" {
    for_each = local.is_local ? [1] : []
    content {
      s3             = var.localstack_endpoint
      sns            = var.localstack_endpoint
      ses            = var.localstack_endpoint
      lambda         = var.localstack_endpoint
      ecs            = var.localstack_endpoint
      iam            = var.localstack_endpoint
      stepfunctions  = var.localstack_endpoint
      cloudwatchlogs = var.localstack_endpoint
      appautoscaling = var.localstack_endpoint
    }
  }

  default_tags {
    tags = {
      Project     = "edc-ingestion-platform"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
