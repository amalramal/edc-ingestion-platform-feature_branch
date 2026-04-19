variable "name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for the cluster"
  type        = bool
  default     = false
}

variable "fargate_spot_weight" {
  description = "Weight for Fargate Spot capacity provider (higher = more preferred)"
  type        = number
  default     = 100
}

variable "fargate_weight" {
  description = "Weight for Fargate (on-demand) capacity provider"
  type        = number
  default     = 0
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
