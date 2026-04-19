# GitHub Actions OIDC Provider and IAM Role
#
# This enables GitHub Actions to authenticate with AWS using short-lived
# OIDC tokens instead of long-lived IAM credentials.

# GitHub OIDC Provider
# This creates the trust relationship between GitHub and AWS
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub's OIDC thumbprint (this is GitHub's certificate thumbprint)
  # AWS now automatically validates GitHub's certificate, but the field is still required
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name = "github-actions-oidc"
  }
}

# IAM Role for GitHub Actions Terraform operations
resource "aws_iam_role" "github_actions_terraform" {
  name        = "github-actions-terraform"
  description = "Role assumed by GitHub Actions for Terraform operations"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Allow from any branch/PR in the specified repositories
            "token.actions.githubusercontent.com:sub" = [for repo in var.github_oidc_repos : "repo:${var.github_oidc_org}/${repo}:*"]
          }
        }
      }
    ]
  })

  tags = {
    Name = "github-actions-terraform"
  }
}
