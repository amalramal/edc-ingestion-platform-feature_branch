resource "aws_wafv2_regex_pattern_set" "path_allow_list" {
  name  = "${var.name}-path-allowlist"
  scope = "REGIONAL"

  dynamic "regular_expression" {
    for_each = var.path_allow_list
    content {
      regex_string = regular_expression.value
    }
  }
}


resource "aws_wafv2_web_acl" "main" {
  name        = "${var.name}-waf"
  description = "${var.name} WAF ACL"
  scope       = "REGIONAL"
  tags        = var.tags

  # Default Action for the entire WAF. Can be Block or Allow
  default_action {
    dynamic "block" {
      for_each = lower(var.waf_default_action) == "block" ? [1] : []
      content {}
    }
    dynamic "allow" {
      for_each = lower(var.waf_default_action) == "allow" ? [1] : []
      content {}
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name}-waf"
    sampled_requests_enabled   = true
  }

  # Regex Pattern Matching Rule Set
  rule {
    name     = "${var.name}-uripath-allowlist"
    priority = 0

    action {
      dynamic "allow" {
        for_each = lower(var.path_allow_list_action) == "allow" ? [1] : []
        content {}
      }
      dynamic "block" {
        for_each = lower(var.path_allow_list_action) == "block" ? [1] : []
        content {}
      }
      dynamic "captcha" {
        for_each = lower(var.path_allow_list_action) == "captcha" ? [1] : []
        content {}
      }
      dynamic "challenge" {
        for_each = lower(var.path_allow_list_action) == "challenge" ? [1] : []
        content {}
      }
      dynamic "count" {
        for_each = lower(var.path_allow_list_action) == "count" ? [1] : []
        content {}
      }
    }

    statement {
      regex_pattern_set_reference_statement {
        arn = aws_wafv2_regex_pattern_set.path_allow_list.arn
        field_to_match {
          uri_path {}
        }
        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-uripath-allowlist"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rulesets
  dynamic "rule" {
    for_each = { for i, r in var.managed_rulesets : i => r }
    content {
      name = rule.value.rule_name
      # Offset by 1 for the pattern matching ruleset above, * 10 to allow other
      # rules to be added in between if necessary
      priority = (rule.key + 1) * 10

      override_action {
        dynamic "count" {
          for_each = lower(rule.value.ruleset_override_action) == "count" ? [1] : []
          content {}
        }
        dynamic "none" {
          for_each = lower(rule.value.ruleset_override_action) == "none" ? [1] : []
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.statement_name
          vendor_name = rule.value.statement_vendor

          dynamic "rule_action_override" {
            for_each = rule.value.rule_overrides != null ? rule.value.rule_overrides : []
            content {
              name = rule_action_override.value.name
              action_to_use {
                dynamic "count" {
                  for_each = lower(rule_action_override.value.action) == "count" ? [1] : []
                  content {}
                }
                dynamic "block" {
                  for_each = lower(rule_action_override.value.action) == "block" ? [1] : []
                  content {}
                }
                dynamic "allow" {
                  for_each = lower(rule_action_override.value.action) == "allow" ? [1] : []
                  content {}
                }
              }
            }
          }
        }
      }
      # Rule Visibility Config
      visibility_config {
        cloudwatch_metrics_enabled = rule.value.enable_cloudwatch_metrics
        metric_name                = rule.value.rule_name
        sampled_requests_enabled   = rule.value.enable_sampled_requests
      }
    }
  }
}


resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}
