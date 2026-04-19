variable "base_domain" {
  description = "The root domain where you want your services deployed"
  type        = string
  default     = null

  validation {
    condition     = var.create_alb ? var.base_domain != null : true
    error_message = "base_domain must be provided when create_alb is true"
  }
}

variable "environment" {
  description = "The name of the environment. Can only be 'dev', 'stage', or 'prod'"
  type        = string

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "Allowed values for environment are 'dev', 'stage', or 'prod'."
  }
}

variable "realm" {
  description = "The name of your realm"
  type        = string
}


#
# OPTIONAL - Keep in alphabetical order
########################################

variable "aws_region" {
  type    = string
  default = "us-east-1"

  validation {
    condition     = contains(["us-east-1"], var.aws_region)
    error_message = "Supported regions are us-east-1"
  }
}

variable "create_alb" {
  description = "Should this module create an ALB?"
  default     = true
  type        = bool
}

variable "create_waf" {
  description = "Attach WAF to the realm-created ALB. Requires create_alb = true (WAF uses module.alb)."
  default     = false
  type        = bool
}

variable "create_ecs_cluster" {
  description = "Should the realm-omnibus create an ECS cluster?"
  default     = false
  type        = bool
}

variable "create_vpc" {
  description = "Should the realm-omnibus create a VPC for you?"
  default     = true
  type        = bool
}

variable "options_ecs_cluster" {
  description = "Configuration options for the ECS cluster"
  type = object({
    enable_container_insights = optional(bool, true)
    fargate_spot_weight       = optional(number, 100)
    fargate_weight            = optional(number, 0)
    tags                      = optional(map(string), {})
  })
  default = {}

}

variable "vpc_cidr" {
  description = "The CIDR block for your VPC"
  type        = string
  default     = null

  validation {
    # Only require a CIDR if var.create_vpc is true
    condition     = var.create_vpc ? var.vpc_cidr != null : true
    error_message = "vpc_cidr must be provided when create_vpc is true"
  }
}

# WAF (when create_waf = true)
variable "waf_allowed_path_regexes" {
  description = "Regex patterns for allowed URI paths (allow-list)"
  type        = list(string)
  default = [
    "^/api/",
    "^/actuator/health",
    "^/assets/",
    "^/static/",
    "^/index\\.html",
    "^/$",
    "^/consul/",
    "^/swagger/"
  ]
}

variable "waf_rate_limit" {
  description = "Max requests per 5 minutes per IP (rate-based rule)"
  type        = number
  default     = 2000
}

variable "waf_managed_rule_action" {
  description = "Managed rules: COUNT (log only) or BLOCK"
  type        = string
  default     = "COUNT"
}
