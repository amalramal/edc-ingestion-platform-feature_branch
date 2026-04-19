# WAF for ALB Module

Start by installing the pre-commit hook by running `pre-commit install` from the **repository root**. Then when you do a commit, the following tools will be run:

  - tflint
  - tf-fmt
  - terraform-docs

To regenerate this README from this module directory, run:

  terraform-docs -c .terraform-docs.yml .

<!-- BEGIN_TF_DOCS -->
## Examples

### Simple

```hcl
module "waf_alb" {
  source = "git::git@github.com:ledgerrun/terraform-modules.git?ref=waf_alb/vX.Y.Z"

  name                 = "${var.realm}-${var.environment}"
  alb_arn              = var.alb_arn
  allowed_path_regexes = var.waf_allowed_path_regexes
  rate_limit           = var.waf_rate_limit
  managed_rule_action  = var.waf_managed_rule_action

  tags = {
    Realm       = var.realm
    Environment = var.environment
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |



## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_wafv2_regex_pattern_set.path_allow_list](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_regex_pattern_set) | resource |
| [aws_wafv2_web_acl.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |
| [aws_wafv2_web_acl_association.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_association) | resource |
| [aws_wafv2_web_acl_logging_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_logging_configuration) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| alb\_arn | ARN of the Application Load Balancer to associate with the WAF Web ACL | `string` | n/a | yes |
| name | Name prefix for WAF Web ACL resources | `string` | n/a | yes |
| enable\_logging\_cloudwatch | Should WAF logs be sent to Cloudwatch? | `bool` | `true` | no |
| managed\_rulesets | A list of the AWS Managed Rulesets to apply to the WAF | <pre>list(object({<br/>    rule_name = string<br/>    rule_overrides = optional(list(object({<br/>      name   = string<br/>      action = string<br/>    })), null)<br/>    ruleset_override_action   = optional(string, "none")<br/>    statement_vendor          = optional(string, "AWS")<br/>    statement_name            = string<br/>    enable_cloudwatch_metrics = optional(bool, true)<br/>    enable_sampled_requests   = optional(bool, true)<br/>  }))</pre> | <pre>[<br/>  {<br/>    "rule_name": "AmazonIpReputation",<br/>    "statement_name": "AWSManagedRulesAmazonIpReputationList"<br/>  },<br/>  {<br/>    "rule_name": "AnonymousIP",<br/>    "rule_overrides": [<br/>      {<br/>        "action": "count",<br/>        "name": "HostingProviderIPList"<br/>      }<br/>    ],<br/>    "statement_name": "AWSManagedRulesAnonymousIpList"<br/>  },<br/>  {<br/>    "rule_name": "SQLInjection",<br/>    "rule_overrides": [<br/>      {<br/>        "action": "count",<br/>        "name": "SQLi_BODY"<br/>      }<br/>    ],<br/>    "statement_name": "AWSManagedRulesSQLiRuleSet"<br/>  },<br/>  {<br/>    "rule_name": "KnownBadInputs",<br/>    "statement_name": "AWSManagedRulesKnownBadInputsRuleSet"<br/>  },<br/>  {<br/>    "rule_name": "CommonRuleSet",<br/>    "rule_overrides": [<br/>      {<br/>        "action": "allow",<br/>        "name": "SizeRestrictions_BODY"<br/>      },<br/>      {<br/>        "action": "count",<br/>        "name": "NoUserAgent_HEADER"<br/>      }<br/>    ],<br/>    "statement_name": "AWSManagedRulesCommonRuleSet"<br/>  },<br/>  {<br/>    "rule_name": "LinuxRuleSet",<br/>    "statement_name": "AWSManagedRulesLinuxRuleSet"<br/>  },<br/>  {<br/>    "rule_name": "UnixRuleSet",<br/>    "statement_name": "AWSManagedRulesUnixRuleSet"<br/>  },<br/>  {<br/>    "rule_name": "WindowsRuleSet",<br/>    "rule_overrides": [<br/>      {<br/>        "action": "allow",<br/>        "name": "WindowsShellCommands_BODY"<br/>      }<br/>    ],<br/>    "statement_name": "AWSManagedRulesWindowsRuleSet"<br/>  }<br/>]</pre> | no |
| path\_allow\_list | Optional list of URI path regex patterns to allow (e.g. ^/reference/wopi/ for WOPI). Requests matching any pattern skip managed rules. Empty = no path allowlist. | `list(string)` | <pre>[<br/>  "^/reference/wopi/",<br/>  "/reference/auth/logout",<br/>  "/international_settlement/tipalti/",<br/>  "^/(budget|contract)/actionWithAttachment",<br/>  "/contract/(contractAction|sendMessageNew)",<br/>  "^/contract/contract/getWopiFileIdForEdit",<br/>  "^/contract/template/getWopiFileIdForEdit",<br/>  "^/contract/template/closeWopiFileForEdit",<br/>  "^/budget/budget/financialExhibitDownload/"<br/>]</pre> | no |
| path\_allow\_list\_action | The action to take for requests matching any of the path\_allow\_list regex patterns | `string` | `"allow"` | no |
| tags | Additional tags for resources | `map(string)` | `{}` | no |
| waf\_default\_action | The default action that the Web ACL should take. | `string` | `"allow"` | no |

## Outputs

| Name | Description |
|------|-------------|
| web\_acl\_arn | ARN of the WAF Web ACL |
| web\_acl\_id | ID of the WAF Web ACL |
<!-- END_TF_DOCS -->
