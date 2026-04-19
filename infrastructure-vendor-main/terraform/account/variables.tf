variable "aws_region" {
  default = "us-east-1"
}

variable "base_domain" {
  default = "ledgerrun.com"
}

# -------- Github OIDC Settings ---------

variable "github_oidc_org" {
  description = "LedgerRun GitHub organization"
  type        = string
  default     = "ledgerrun"
}

variable "github_oidc_repos" {
  description = "List of Github Repos allowed to Assume a role in the AWS account"
  type        = list(string)
  default = [
    "edc-ingestion-platform",
  ]
}
