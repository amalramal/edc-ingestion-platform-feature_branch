resource "aws_flow_log" "vpc_flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  log_destination      = var.create_vpc_flow_log_bucket ? aws_s3_bucket.vpc_flow_logs_bucket[0].arn : var.vpc_flow_log_s3_bucket_arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.vpc.id

  tags = var.vpc_tags
}

resource "aws_s3_bucket" "vpc_flow_logs_bucket" {
  count = var.enable_vpc_flow_logs && var.create_vpc_flow_log_bucket ? 1 : 0

  bucket = "${var.project_name}-vpc-flow-logs"
  tags   = var.vpc_tags
}
