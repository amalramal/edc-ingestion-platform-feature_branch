data "aws_vpc_endpoint_service" "gateway_service" {
  for_each = toset(var.gateway_endpoints)

  service      = each.key
  service_type = "Gateway"
}

resource "aws_vpc_endpoint" "gateway_endpoint" {
  for_each = data.aws_vpc_endpoint_service.gateway_service

  vpc_id            = aws_vpc.vpc.id
  service_name      = data.aws_vpc_endpoint_service.gateway_service[each.key].service_name
  vpc_endpoint_type = data.aws_vpc_endpoint_service.gateway_service[each.key].service_type

  tags = merge(
    var.vpc_tags,
    {
      Name = "${var.project_name}-${each.key}"
    }
  )
}

resource "aws_vpc_endpoint_route_table_association" "private" {
  for_each = { for product in setproduct(var.gateway_endpoints, values(local.private_networks_by_az)) : "${product[0]}-${product[1]["availability_zone"]}" => { endpoint = product[0], name = product[1]["availability_zone"] } }

  vpc_endpoint_id = aws_vpc_endpoint.gateway_endpoint[each.value.endpoint].id
  route_table_id  = aws_route_table.private_rt[each.value.name].id
}

resource "aws_vpc_endpoint_route_table_association" "public" {
  for_each = { for product in setproduct(var.gateway_endpoints, values(local.public_networks_by_az)) : "${product[0]}-${product[1]["availability_zone"]}" => { endpoint = product[0], name = product[1]["availability_zone"] } }

  vpc_endpoint_id = aws_vpc_endpoint.gateway_endpoint[each.value.endpoint].id
  route_table_id  = aws_route_table.public_rt[each.value.name].id
}
