variable "name" {
  description = "Name prefix for WAF Web ACL resources"
  type        = string
}

variable "alb_arn" {
  description = "ARN of the Application Load Balancer to associate with the WAF Web ACL"
  type        = string
}

variable "waf_default_action" {
  description = "The default action that the Web ACL should take."
  type        = string
  default     = "allow"

  validation {
    condition     = contains(["allow", "block"], lower(var.waf_default_action))
    error_message = "Default action must be one of 'allow' or 'block'"
  }
}

variable "enable_logging_cloudwatch" {
  description = "Should WAF logs be sent to Cloudwatch?"
  type        = bool
  default     = true
}

variable "path_allow_list" {
  description = "Optional list of URI path regex patterns to allow (e.g. ^/reference/wopi/ for WOPI). Requests matching any pattern skip managed rules. Empty = no path allowlist."
  type        = list(string)
  default = [
    "^/reference/wopi/",
    "/reference/auth/logout",
    "/international_settlement/tipalti/",
    "^/(budget|contract)/actionWithAttachment",
    "/contract/(contractAction|sendMessageNew)",
    "^/contract/contract/getWopiFileIdForEdit",
    "^/contract/template/getWopiFileIdForEdit",
    "^/contract/template/closeWopiFileForEdit",
    "^/budget/budget/financialExhibitDownload/"
  ]
}

variable "path_allow_list_action" {
  description = "The action to take for requests matching any of the path_allow_list regex patterns"
  type        = string
  default     = "allow"

  validation {
    condition     = contains(["allow", "block", "captcha", "challenge", "count"], lower(var.path_allow_list_action))
    error_message = "Default action must be one of 'allow', 'block', 'captcha', 'challenge', 'count'"
  }
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

variable "managed_rulesets" {
  description = "A list of the AWS Managed Rulesets to apply to the WAF"
  type = list(object({
    rule_name = string
    rule_overrides = optional(list(object({
      name   = string
      action = string
    })), null)
    ruleset_override_action   = optional(string, "none")
    statement_vendor          = optional(string, "AWS")
    statement_name            = string
    enable_cloudwatch_metrics = optional(bool, true)
    enable_sampled_requests   = optional(bool, true)
  }))

  default = [
    {
      rule_name      = "AmazonIpReputation"
      statement_name = "AWSManagedRulesAmazonIpReputationList"
    },
    {
      rule_name      = "AnonymousIP"
      statement_name = "AWSManagedRulesAnonymousIpList"
      rule_overrides = [
        { name = "HostingProviderIPList", action = "count" }
      ]
    },
    {
      rule_name      = "SQLInjection"
      statement_name = "AWSManagedRulesSQLiRuleSet"
      rule_overrides = [
        { name = "SQLi_BODY", action = "count" }
      ]
    },
    {
      rule_name      = "KnownBadInputs"
      statement_name = "AWSManagedRulesKnownBadInputsRuleSet"
    },
    {
      rule_name      = "CommonRuleSet"
      statement_name = "AWSManagedRulesCommonRuleSet",
      rule_overrides = [
        { name = "SizeRestrictions_BODY", action = "allow" },
        { name = "NoUserAgent_HEADER", action = "count" }
      ]
    },
    {
      rule_name      = "LinuxRuleSet"
      statement_name = "AWSManagedRulesLinuxRuleSet"
    },
    {
      rule_name      = "UnixRuleSet"
      statement_name = "AWSManagedRulesUnixRuleSet"
    },
    {
      rule_name      = "WindowsRuleSet"
      statement_name = "AWSManagedRulesWindowsRuleSet"
      rule_overrides = [
        { name = "WindowsShellCommands_BODY", action = "allow" }
      ]
    }
  ]
}
