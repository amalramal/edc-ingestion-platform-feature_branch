resource "aws_subnet" "public_subnets" {
  for_each = local.public_networks_by_az

  availability_zone       = each.value["availability_zone"]
  cidr_block              = each.value["cidr_block"]
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.vpc.id
  tags = merge(
    var.vpc_tags,
    var.subnet_tags,
    var.public_subnet_tags,
    {
      Name        = "${each.value["name"]}-sn"
      NetworkType = "public"
    }
  )
}

resource "aws_route_table" "public_rt" {
  for_each = local.public_networks_by_az

  vpc_id = aws_vpc.vpc.id
  tags = merge(
    var.vpc_tags,
    {
      Name        = "${each.value["name"]}-rt"
      NetworkType = "public"
    }
  )
}

resource "aws_route" "public_internet_gateway_route" {
  for_each = local.public_networks_by_az

  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.vpc_igw[0].id
  route_table_id         = aws_route_table.public_rt[each.key].id
}

resource "aws_route_table_association" "public_route_table_association" {
  for_each = local.public_networks_by_az

  route_table_id = aws_route_table.public_rt[each.key].id
  subnet_id      = aws_subnet.public_subnets[each.key].id
}
