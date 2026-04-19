output "vpc_id" {
  value       = var.create_vpc ? module.vpc[0].vpc_id : ""
  description = "The ID of the created VPC"
}

output "waf_web_acl_arn" {
  value       = var.create_waf && var.create_alb ? module.waf_alb[0].web_acl_arn : null
  description = "ARN of the WAF Web ACL (when create_waf = true)"
}

output "waf_web_acl_id" {
  value       = var.create_waf && var.create_alb ? module.waf_alb[0].web_acl_id : null
  description = "ID of the WAF Web ACL (when create_waf = true)"
}
