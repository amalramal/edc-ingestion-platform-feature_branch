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
module "new_module" {
  source = "git::git@github.com:ledgerrun/terraform-modules.git?ref=<TEMPLATE>/vX.Y.Z"

  # ...
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >1.0.0 |

<!-- END_TF_DOCS -->
