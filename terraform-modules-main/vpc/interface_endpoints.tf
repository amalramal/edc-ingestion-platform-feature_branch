data "aws_vpc_endpoint_service" "interface" {
  for_each = toset(var.interface_endpoints)

  service      = each.key
  service_type = "Interface"
}

resource "aws_security_group" "interface" {
  for_each = toset(var.interface_endpoints)

  description = "Allow traffic from private subnets to ${each.key}"
  name        = "interface-aws-${each.key}"
  vpc_id      = aws_vpc.vpc.id
}

resource "aws_security_group_rule" "interface_ingress" {
  for_each = toset(var.interface_endpoints)

  cidr_blocks       = [for _, sub in aws_subnet.private_subnets : sub.cidr_block]
  description       = "Allow traffic from private subnets to ${each.key}"
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.interface[each.key].id
  to_port           = 0
  type              = "ingress"
}

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(var.interface_endpoints)

  private_dns_enabled = true
  service_name        = data.aws_vpc_endpoint_service.interface[each.key].service_name
  vpc_endpoint_type   = "Interface"
  vpc_id              = aws_vpc.vpc.id

  security_group_ids = [
    aws_security_group.interface[each.key].id,
  ]

  subnet_ids = [for _, sub in aws_subnet.private_subnets : sub.id]

  tags = merge(
    var.vpc_tags,
    {
      Name = "${var.project_name}-${each.key}"
    }
  )
}
