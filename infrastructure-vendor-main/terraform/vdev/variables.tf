# -------- General Settings ---------

variable "aws_load_balancer_controller_helm_version" {
  description = "The chart version of AWS LBC to install. See Latest version at https://github.com/aws/eks-charts/tree/master/stable/aws-load-balancer-controller"
  default     = "3.2.1"
}

variable "aws_profile" {
  description = "The name of the AWS profile to use"
  default     = "vendor-admin"
}

variable "aws_region" {
  default = "us-east-1"
}

variable "base_domain" {
  default = "ledgerrun.com"
}

variable "environment" {
  description = "The name of the environment"
  default     = "vdev"
}

variable "vpc_cidr" {
  default = "10.11.0.0/18" # 10.11.0.0 - 10.11.63.254, n=16384
}
