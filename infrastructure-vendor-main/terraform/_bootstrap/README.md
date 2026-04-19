# LedgerRun Vendor AWS Bootstrap

Creates the Terraform State S3 bucket.

## Running this Terraform

At first, no S3 bucket will be available. Comment out the contents of `backend.tf` and run your terraform plan and apply. This will create a local state file.

With the bucket created, uncomment the contents of `backend.tf` and migrate the state into the S3 bucket:

```
terraform init -migrate-state
```
