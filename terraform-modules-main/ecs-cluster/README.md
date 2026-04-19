# ECS Cluster Module

This module will install an AWS ECS Cluster for you.

Start by installing the pre-commit hook by running `pre-commit install`.  Then when you to do a commit, the following tools will be run

  - tflint
  - tf-fmt
  - terraform-docs

<!-- BEGIN_TF_DOCS -->
## Examples

### Simple

```hcl
module "new_module" {
  source = "git::git@github.com:ledgerrun/terraform-modules.git?ref=ecs-cluster/vX.Y.Z"

  name = "<REALM>-<ENV>"
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
| [aws_ecs_cluster.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_cluster_capacity_providers.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster_capacity_providers) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Name of the ECS cluster | `string` | n/a | yes |
| enable\_container\_insights | Enable CloudWatch Container Insights for the cluster | `bool` | `false` | no |
| fargate\_spot\_weight | Weight for Fargate Spot capacity provider (higher = more preferred) | `number` | `100` | no |
| fargate\_weight | Weight for Fargate (on-demand) capacity provider | `number` | `0` | no |
| tags | Additional tags for resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster\_arn | ARN of the ECS cluster |
| cluster\_id | ID of the ECS cluster |
| cluster\_name | Name of the ECS cluster |
<!-- END_TF_DOCS -->
