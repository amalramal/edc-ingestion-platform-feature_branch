# variable "environment" {
#   description = "The name of the environment. Can only be 'dev', 'stage', or 'prod'"
#   type        = string

#   validation {
#     condition     = contains(["dev", "stage", "prod"], var.environment)
#     error_message = "Allowed values for environment are 'dev', 'stage', or 'prod'."
#   }
# }

variable "deployment_environment" {
  description = "The name of the environment in which to deploy"
  type        = string

  validation {
    condition     = contains(["dev", "qa", "uat", "eval", "ppd", "feature", "preview", "prod"], var.deployment_environment)
    error_message = "Must be one of 'dev', 'qa', 'uat', 'eval', 'ppd', 'feature', 'preview', 'prod'"
  }
}

variable "realm" {
  description = "The realm where your service should be deployed."
  type        = string
}

variable "service_name" {
  description = "The name of your service. i.e. budget-service, gateway-service, etc"
  type        = string
}

#
# Optional
##################

variable "aws_region" {
  default     = "us-east-1"
  description = "The AWS Region"
  type        = string
}

variable "create_ecr_repository" {
  description = "Should an ECR repository be created for this service?"
  default     = true
  type        = bool
}

variable "ecr_tag_mutability" {
  description = "The mutability of the ECR images."
  default     = "MUTABLE"
  type        = string
}

variable "ecr_scan_on_push" {
  description = "Scan the container for vulnerabilities on push?"
  type        = bool
  default     = true
}

variable "github_actions_repository" {
  description = "Grant OIDC Authorization for this repository"
  type        = string
  default     = "ledgerrun/*"
}
