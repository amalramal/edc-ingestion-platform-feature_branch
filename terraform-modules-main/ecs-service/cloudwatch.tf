# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/${local.service_realm_name}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "${local.service_realm_name}-logs"
  })
}
