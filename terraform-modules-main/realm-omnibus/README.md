# Example Terraform Module

This is an example terraform module, it should be expanded apon and the readme should be updated to track what is being done in this module

This example module has some nice features built in by default.

Start by installing the pre-commit hook by running `pre-commit install`.  Then when you to do a commit, the following tools will be run

  - tflint
  - tf-fmt
  - terraform-docs

<!-- BEGIN_TF_DOCS -->
## Examples

### Simple

```hcl
provider "aws" {
  region  = "us-east-1"
  profile = "lr-production"

  default_tags {
    tags = {
      project     = "clinrun"
      account     = "clinrun-legacy"
      environment = "dev"
      layer       = "realm"
      managedby   = "terraform"
      realm       = "<REALM>"
    }
  }
}


module "realm" {
  source = "git::git@github.com:ledgerrun/terraform-modules.git?ref=<TEMPLATE>/vX.Y.Z"

  environment = "dev"
  realm       = "<REALM>"
  vpc_cidr    = "172.16.64.0/18"

  create_ecs_cluster = true
  options_ecs_cluster = {
    enable_container_insights = false
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >1.0.0 |
| aws | >= 6.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 6.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| alb | git::git@github.com:ledgerrun/terraform-modules.git | alb/v1.0.0 |
| ecs\_cluster | git::git@github.com:ledgerrun/terraform-modules.git | ecs-cluster/v1.0.0 |
| vpc | git::git@github.com:ledgerrun/terraform-modules.git | vpc/v1.0.0 |

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.cert](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_route53_record.realm_ns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_zone.realm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |
| [aws_route53_zone.base_domain](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | The name of the environment. Can only be 'dev', 'stage', or 'prod' | `string` | n/a | yes |
| realm | The name of your realm | `string` | n/a | yes |
| aws\_region | n/a | `string` | `"us-east-1"` | no |
| base\_domain | The root domain where you want your services deployed | `string` | `null` | no |
| create\_alb | Should this module create an ALB? | `bool` | `true` | no |
| create\_ecs\_cluster | Should the realm-omnibus create an ECS cluster? | `bool` | `false` | no |
| create\_vpc | Should the realm-omnibus create a VPC for you? | `bool` | `true` | no |
| options\_ecs\_cluster | Configuration options for the ECS cluster | <pre>object({<br/>    enable_container_insights = optional(bool, true)<br/>    fargate_spot_weight       = optional(number, 100)<br/>    fargate_weight            = optional(number, 0)<br/>    tags                      = optional(map(string), {})<br/>  })</pre> | `{}` | no |
| vpc\_cidr | The CIDR block for your VPC | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc\_id | The ID of the created VPC |
<!-- END_TF_DOCS -->
