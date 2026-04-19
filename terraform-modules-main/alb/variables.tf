variable "name" {
  description = "Name prefix for ALB resources"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "IDs of subnets for the ALB (should be public subnets)"
  type        = list(string)
}

variable "internal" {
  description = "Whether the ALB is internal (not internet-facing)"
  type        = bool
  default     = false
}

variable "idle_timeout" {
  description = "Idle timeout for the ALB in seconds"
  type        = number
  default     = 60
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

variable "certificate_arn" {
  description = "ARN of ACM certificate for HTTPS listener. If provided, HTTPS listener will be created."
  type        = string
  default     = null
}

variable "ssl_policy" {
  description = "SSL policy for HTTPS listener"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}
