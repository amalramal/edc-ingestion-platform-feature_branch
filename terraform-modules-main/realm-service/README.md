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
module "realm_service" {
  source = "git::git@github.com:ledgerrun/terraform-modules.git?ref=realm-service/vX.Y.Z"

  deployment_environment = "prod"
  realm                  = "infra"
  service_name           = "my-service"
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >1.0.0 |
| aws | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |



## Resources

| Name | Type |
|------|------|
| [aws_ecr_repository.repo](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |
| [aws_iam_role.github_actions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.github_ecr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.ecr_push](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.github_actions_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| deployment\_environment | The name of the environment in which to deploy | `string` | n/a | yes |
| realm | The realm where your service should be deployed. | `string` | n/a | yes |
| service\_name | The name of your service. i.e. budget-service, gateway-service, etc | `string` | n/a | yes |
| aws\_region | The AWS Region | `string` | `"us-east-1"` | no |
| create\_ecr\_repository | Should an ECR repository be created for this service? | `bool` | `true` | no |
| ecr\_scan\_on\_push | Scan the container for vulnerabilities on push? | `bool` | `true` | no |
| ecr\_tag\_mutability | The mutability of the ECR images. | `string` | `"MUTABLE"` | no |
| github\_actions\_repository | Grant OIDC Authorization for this repository | `string` | `"ledgerrun/*"` | no |

<!-- END_TF_DOCS -->
