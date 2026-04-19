resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(
    var.vpc_tags,
    {
      Name = "${var.project_name}-vpc"
    }
  )
}

resource "aws_vpc_dhcp_options" "vpc_dhcp" {
  domain_name         = var.internal_domain_name
  domain_name_servers = var.domain_name_servers
  tags = merge(
    var.vpc_tags,
    {
      Name = var.project_name
    }
  )
}

resource "aws_vpc_dhcp_options_association" "dns_option_assoc" {
  vpc_id          = aws_vpc.vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.vpc_dhcp.id
}

resource "aws_network_acl" "vpc_network_acl" {
  vpc_id     = aws_vpc.vpc.id
  subnet_ids = concat([for k, sub in aws_subnet.public_subnets : sub.id], [for k, sub in aws_subnet.private_subnets : sub.id])
  egress {
    protocol   = "all"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  ingress {
    protocol   = "all"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  tags = merge(
    var.vpc_tags,
    {
      Name = var.project_name
    }
  )
}

resource "aws_internet_gateway" "vpc_igw" {
  count  = var.enable_igw ? 1 : 0
  vpc_id = aws_vpc.vpc.id
  tags = merge(
    var.vpc_tags,
    {
      Name = "${var.project_name}-vpc-igw"
    }
  )
}
