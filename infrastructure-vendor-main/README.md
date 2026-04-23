# Infrastructure LedgerRun Vendor

## AWS SSO Setup

In your `~/.aws/config` file:

```
[sso-session ledgerrun]
sso_start_url = https://ledgerrun.awsapps.com/start
sso_region = us-east-1
sso_registration_scopes = sso:account:access

[profile vendor-sa]
sso_session = ledgerrun
sso_account_id = 130695430172
sso_role_name = vendor-poweruser
region = us-east-1
```

You should then be able to authenticate using the aws CLI:

```
aws sso login --profile vendor-poweruser
```

## AWS Resource Tagging Strategy

This document defines the standard tagging strategy for all AWS resources managed by this repository.

### Required Tags

All resources MUST have these tags (applied automatically via provider `default_tags`):

| Tag | Description | Example Values |
|-----|-------------|----------------|
| `Project` | Top-level project identifier | `ledgerrun` |
| `Account` | AWS account identifier | `ledgerrun-vendor` |
| `Environment` | Deployment environment | `vdev`, `vstaging` |
| `Layer` | Infrastructure layer | `infrastructure`, `service` |
| `ManagedBy` | How the resource is managed | `terraform` |
| `Repository` | Source code repository | `infrastructure-vendor` |

### Provider Default Tags

Each Terraform layer defines default tags in `providers.tf`:

```hcl
provider "aws" {
  default_tags {
    tags = {
      Project     = "ledgerrun"
      Account     = "ledgerrun-vendor"
      Environment = var.environment
      Layer       = "service"
      Service     = "my-service"  # Only in service layer
      ManagedBy   = "terraform"
      Repository  = "infrastructure-vendor"
    }
  }
}
```

### Tag Naming Conventions

- Use lowercase for tag values
- Use hyphens for multi-word values (e.g., `engineering-operations`)
- Keep values concise but descriptive
- Environment names: `production`, `staging`, `dev` (not `prod`, `stg`)

