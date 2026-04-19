data "aws_availability_zone" "available" {
  count = length(var.subnet_zone_list)
  name  = "${var.aws_region}${var.subnet_zone_list[count.index]}"
  state = "available"
}
