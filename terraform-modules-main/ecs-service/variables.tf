variable "environment" {
  default = "The name of the environment this service is deployed into. Can be 'dev', 'stage', or 'prod'"
  type    = string
  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "Allowed values for environment are 'dev', 'stage', or 'prod'."
  }
}

variable "deployment_environment" {
  description = "The name of the environment in which to deploy"
  type        = string

  validation {
    condition     = contains(["dev", "qa", "uat", "eval", "ppd", "feature", "preview", "prod"], var.deployment_environment)
    error_message = "Must be one of 'dev', 'qa', 'uat', 'eval', 'ppd', 'feature', 'preview', 'prod'"
  }
}

variable "service_name" {
  description = "Name of the ECS service"
  type        = string
}

variable "realm" {
  description = "The name of the realm"
  type        = string
}


variable "container_definition" {
  description = "Configuration Options for the ECS Container"
  type = object({
    image       = string
    image_tag   = string
    web_ui_port = number

    # Optional
    command       = optional(list(string), null)
    desired_count = optional(number, 1)
    environment_variables = optional(list(object({
      name  = string
      value = any
    })), null)
    essential = optional(bool, true)
    logdriver = optional(string, "awslogs")
    mount_points = optional(list(object({
      sourceVolume  = string
      containerPath = string
      readOnly      = bool
    })), null)
    port_mappings = optional(list(object({
      name          = string
      containerPort = number
      hostPort      = number
      protocol      = string
    })), null)
    user = optional(string, null)
  })
}

# OPTIONAL
#####################

variable "base_domain" {
  description = "The base domain of the URL you want to deploy to"
  type        = string
  default     = "ledgerrun.com"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "module_tags" {
  description = "A list of tags for each resource in this module"
  type        = map(string)
  default = {
    "managedby" = "terraform"
    "tfmodule"  = "ecs-service"
  }
}

variable "nlb_config" {
  description = "NLB listener configuration. Required when use_nlb = true."
  type = object({
    listeners = map(object({
      protocol           = string # "TCP" or "TLS"
      port               = number # NLB/Internet listener port (443 for HTTPS)
      target_port        = number # container port to forward to
      preserve_client_ip = optional(bool, true)
      health_check = optional(object({
        enabled             = optional(bool, true)
        healthy_threshold   = optional(number, 3)
        unhealthy_threshold = optional(number, 3)
        interval            = optional(number, 10)
        protocol            = optional(string, "TCP")
        path                = optional(string, null)
        port                = optional(string, "traffic-port")
        matcher             = optional(string, null)
      }), null)
    }))
  })
  default = null
}

variable "secrets_manager_secrets" {
  description = "A list of AWS SecretsManager Secrets to include in the container defintion. A secrets manager secret named $realm/$deploy_env/$service will also be created."
  default     = []
  type        = list(string)
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

variable "task_definition" {
  description = "Configuration Options for the ECS Task Definition"
  default     = {}
  type = object({
    enable_execute_command        = optional(bool, false)
    attach_execution_iam_policies = optional(list(string), [])
    attach_task_iam_policies      = optional(list(string), [])
    network_mode                  = optional(string, "awsvpc")
    force_new_deployment          = optional(bool, true)
    requires_compatibilities      = optional(list(string), ["FARGATE"])
    cpu                           = optional(number, 256)
    memory                        = optional(number, 512)
    fargate_spot_capacity         = optional(number, 100)
    fargate_capacity              = optional(number, 0)
    sg_ingress = optional(list(object({
      from_port       = number
      to_port         = number
      protocol        = optional(string, "tcp")
      security_groups = optional(list(string), [])
      cidr_blocks     = optional(list(string), [])
      description     = string
    })), null)
    efs_volumes = optional(list(object({
      name           = string
      file_system_id = string
      root_directory = string
    })), null)
  })
}

variable "use_alb" {
  description = "Whether to create ALB resources (target group, listener rule, ALB ingress)"
  type        = bool
  default     = true
}

variable "use_nlb" {
  description = "Whether to create an NLB for this service"
  type        = bool
  default     = false
}

locals {
  service_realm_name = "${var.service_name}-${var.realm}-${var.environment}"
  realm_name         = "${var.realm}-${var.environment}"
  tags               = merge(var.tags, var.module_tags, { "environment" : var.environment })

  nlb_listeners = var.use_nlb ? var.nlb_config.listeners : {}
  nlb_tls_listeners = {
    for k, l in local.nlb_listeners :
    k => l if l.protocol == "TLS"
  }
  nlb_tcp_listeners = {
    for k, l in local.nlb_listeners :
    k => l if l.protocol == "TCP"
  }
}
