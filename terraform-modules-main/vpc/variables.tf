variable "aws_region" {
  description = "This is the region that you want to create the resources in."
  type        = string
}

variable "create_vpc_flow_log_bucket" {
  default     = false
  type        = bool
  description = "Create a vpc flow log bucket, requires `enable_vpc_flow_logs` to equal true"
}

variable "domain_name_servers" {
  type        = list(any)
  default     = ["AmazonProvidedDNS"]
  description = "Additional DNS servers"
}

variable "enable_priv_subnets" {
  description = "Enable the private subnets"
  default     = true
  type        = bool
}

variable "enable_public_subnets" {
  description = "Enable the private subnets"
  default     = true
  type        = bool
}

variable "enable_igw" {
  description = "Creates Interet Gateway if set to true"
  default     = true
  type        = bool
}

variable "enable_vpc_flow_logs" {
  default     = false
  type        = bool
  description = "Enable VPC Flow Logs"
}

variable "gateway_endpoints" {
  type        = set(string)
  default     = ["s3"]
  description = "A gateway that you specify as a target for a route in your route table for traffic destined to a supported AWS service. Currently supports S3 and DynamoDB services."
}

variable "interface_endpoints" {
  type        = set(string)
  default     = []
  description = "Names of AWS services for which to create PrivateLink interfaces in the VPC."
}

variable "internal_domain_name" {
  description = "This is the domain name to use within the VPC."
  default     = "ec2.internal"
  type        = string
}

variable "project_name" {
  description = "This is the name you want the VPC and related resources to have.  This is useful if running multiple projects in the same region + account."
  type        = string
}

variable "public_subnet_newbits" {
  default     = 6
  description = "Number of bits to add to vpc_cidr to create public subnet size. Ex. if vpc_cidr is 10.0.0.0/16 and newbits is 4, then subnets are /20."
  type        = number
}

variable "private_subnet_newbits" {
  default     = 3
  description = "Number of bits to add to vpc_cidr to create private subnet size. Ex. if vpc_cidr is 10.0.0.0/16 and newbits is 4, then subnets are /20."
  type        = number
}

variable "subnet_tags" {
  description = "Tags that are applied to all subnets"
  type        = map(string)
  default     = {}
}

variable "public_subnet_tags" {
  description = "Tags that are applied to public subnets only"
  type        = map(string)
  default     = {}
}

variable "private_subnet_tags" {
  description = "Tags that are applied to private subnets only"
  type        = map(string)
  default     = {}
}

variable "subnet_zone_list" {
  type        = list(string)
  default     = ["a", "b", "c"]
  description = "The AZs to provision subnets for"
}

variable "vpc_flow_log_s3_bucket_arn" {
  default     = ""
  type        = string
  description = "Bucket ARN for the VPC Flow Logs"
}

variable "vpc_cidr" {
  description = "Default IP CIDR block you want to use with the VPC (eg 10.0.0.0/18 or 10.0.64.0/18), see wiki page for in use cidrs: https://sparefoot.atlassian.net/l/cp/k111K3GV"
  type        = string
}

variable "vpc_tags" {
  description = "Tags that are applied to all resources of the VPC"
  type        = map(string)
  default     = {}
}


locals {
  num_priv_subnets   = var.enable_priv_subnets ? length(var.subnet_zone_list) : 0
  num_public_subnets = var.enable_public_subnets ? length(var.subnet_zone_list) : 0

  private_networks = [for i in range(local.num_priv_subnets) : {
    availability_zone = data.aws_availability_zone.available[i].name
    name              = "${var.project_name}-priv-${data.aws_availability_zone.available[i].name}"
    new_bits          = var.private_subnet_newbits
  }]

  public_networks = [for i in range(local.num_public_subnets) : {
    availability_zone = data.aws_availability_zone.available[i].name
    name              = "${var.project_name}-pub-${data.aws_availability_zone.available[i].name}"
    new_bits          = var.public_subnet_newbits
  }]

  all_networks = concat(local.private_networks, local.public_networks)

  # https://github.com/hashicorp/terraform-cidr-subnets/blob/master/main.tf
  addrs_by_idx = cidrsubnets(var.vpc_cidr, local.all_networks[*].new_bits...)
  network_objs = [for i, n in local.all_networks : {
    availability_zone = n.availability_zone
    cidr_block        = n.name != null ? local.addrs_by_idx[i] : tostring(null)
    name              = n.name
    new_bits          = n.new_bits
  }]

  private_networks_by_az = { for net in slice(local.network_objs, 0, local.num_priv_subnets) : net["availability_zone"] => net }
  public_networks_by_az  = { for net in slice(local.network_objs, local.num_priv_subnets, local.num_priv_subnets + local.num_public_subnets) : net["availability_zone"] => net }
}
