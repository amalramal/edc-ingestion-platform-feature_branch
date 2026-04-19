resource "aws_cloudwatch_log_group" "this" {
  count = var.enable_logging_cloudwatch ? 1 : 0
  # Per AWS, WAF Log Groups must begin with `aws-waf-logs-`
  name = "aws-waf-logs-${var.name}"
  tags = var.tags
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count                   = var.enable_logging_cloudwatch ? 1 : 0
  log_destination_configs = [aws_cloudwatch_log_group.this[0].arn]
  resource_arn            = aws_wafv2_web_acl.main.arn
}
