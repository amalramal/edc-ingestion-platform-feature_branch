output "interface_endpoints" {
  description = "Interface Endpoints"
  value       = aws_vpc_endpoint.interface
}

output "interface_endpoint_security_groups" {
  description = "Interface Endpoint Security Groups"
  value       = aws_security_group.interface
}

output "private_subnet_ids" {
  description = "Private Subnet IDs"
  value       = [for _, sub in aws_subnet.private_subnets : sub.id]
}

output "private_subnet_cidrs" {
  description = "Private Subent CIRDS"
  value       = [for _, sub in aws_subnet.private_subnets : sub.cidr_block]
}

output "private_route_tables" {
  description = "Private Subnet Route Tables"
  value       = [for _, rt in aws_route_table.private_rt : rt.id]
}

output "public_subnet_ids" {
  description = "Public Subnet ID's"
  value       = [for _, sub in aws_subnet.public_subnets : sub.id]
}

output "public_subnet_cidrs" {
  description = "Public Subnet CIRD's"
  value       = [for _, sub in aws_subnet.public_subnets : sub.cidr_block]
}

output "public_route_tables" {
  description = "Public Route Tables"
  value       = [for _, rt in aws_route_table.public_rt : rt.id]
}

output "public_nat_gateways_by_region" {
  value = {
    for key in keys(aws_nat_gateway.nat_gateway) :
    key => aws_nat_gateway.nat_gateway[key].id
  }

  description = "An Object with region and nat gateway for that region"
}

output "public_nat_gateway_cidrs" {
  description = "Public CIDRs for the NAT Gateways"
  value       = [for _, gt in aws_nat_gateway.nat_gateway : "${gt.public_ip}/32"]
}

output "gateway_endpoints_by_service" {
  description = "Object with the service and it's endpoint"
  value = {
    for key in keys(aws_vpc_endpoint.gateway_endpoint) :
    key => aws_vpc_endpoint.gateway_endpoint[key].id
  }
}

output "vpc_cidr" {
  description = "VPC CIRD"
  value       = var.vpc_cidr
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.vpc.id
}
