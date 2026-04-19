# AWS ALB Module

Start by installing the pre-commit hook by running `pre-commit install`.  Then when you to do a commit, the following tools will be run

  - tflint
  - tf-fmt
  - terraform-docs

<!-- BEGIN_TF_DOCS -->
## Examples

### Simple

```hcl
module "new_module" {
  source = "git::git@github.com:ledgerrun/terraform-modules.git?ref=alb/vX.Y.Z"

  name       = "${var.relam}-${var.environment}"
  vpc_id     = local.vpc_id
  subnet_ids = local.public_subnet_ids

  tags = {
    env = var.environment
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
| [aws_lb.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_security_group.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Name prefix for ALB resources | `string` | n/a | yes |
| subnet\_ids | IDs of subnets for the ALB (should be public subnets) | `list(string)` | n/a | yes |
| vpc\_id | ID of the VPC | `string` | n/a | yes |
| certificate\_arn | ARN of ACM certificate for HTTPS listener. If provided, HTTPS listener will be created. | `string` | `null` | no |
| idle\_timeout | Idle timeout for the ALB in seconds | `number` | `60` | no |
| internal | Whether the ALB is internal (not internet-facing) | `bool` | `false` | no |
| ssl\_policy | SSL policy for HTTPS listener | `string` | `"ELBSecurityPolicy-TLS13-1-2-2021-06"` | no |
| tags | Additional tags for resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| alb\_arn | ARN of the ALB |
| alb\_dns\_name | DNS name of the ALB |
| alb\_id | ID of the ALB |
| alb\_zone\_id | Route53 zone ID of the ALB |
| http\_listener\_arn | ARN of the HTTP listener |
| https\_listener\_arn | ARN of the HTTPS listener |
| security\_group\_id | ID of the ALB security group |
<!-- END_TF_DOCS -->
