resource "aws_subnet" "private_subnets" {
  for_each = local.private_networks_by_az

  availability_zone = each.value["availability_zone"]
  cidr_block        = each.value["cidr_block"]
  vpc_id            = aws_vpc.vpc.id
  tags = merge(
    var.subnet_tags,
    var.private_subnet_tags,
    var.vpc_tags,
    {
      Name        = "${each.value["name"]}-sn"
      NetworkType = "private"
    }
  )
}

resource "aws_eip" "nat_eip" {
  # We don't need EIPs if we dont have an IGW
  for_each = var.enable_igw ? local.private_networks_by_az : {}

  domain = "vpc"
  tags = merge(
    var.vpc_tags,
    {
      Name = "${each.value["name"]}-nat-ip"
    }
  )
}

resource "aws_nat_gateway" "nat_gateway" {
  # Only create NAT Gateways if we have public subnets to attach them to
  for_each = local.num_public_subnets > 0 ? local.public_networks_by_az : {}

  allocation_id = aws_eip.nat_eip[each.key].id
  subnet_id     = aws_subnet.public_subnets[each.key].id
  tags = merge(
    var.vpc_tags,
    {
      Name = "${each.key}-nat-gw"
    }
  )
}

resource "aws_route_table" "private_rt" {
  for_each = local.private_networks_by_az

  vpc_id = aws_vpc.vpc.id
  tags = merge(
    var.vpc_tags,
    {
      Name        = "${each.value["name"]}-rt"
      NetworkType = "private"
    }
  )
}

resource "aws_route" "private_nat_route" {
  # We only need routes if the public subnets exist
  for_each = local.num_public_subnets > 0 ? local.private_networks_by_az : {}

  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway[each.key].id
  route_table_id         = aws_route_table.private_rt[each.key].id
}

resource "aws_route_table_association" "private_route_table_assciation" {
  for_each = local.private_networks_by_az

  route_table_id = aws_route_table.private_rt[each.key].id
  subnet_id      = aws_subnet.private_subnets[each.key].id
}
