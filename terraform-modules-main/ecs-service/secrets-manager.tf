resource "aws_secretsmanager_secret" "service" {
  count = length(var.secrets_manager_secrets) > 0 ? 1 : 0

  name                    = "${var.realm}/${var.deployment_environment}/${var.service_name}"
  description             = "Secret for ${var.service_name}. Should contain Key/Value pairs"
  recovery_window_in_days = 7

  tags = local.tags
}

resource "aws_iam_policy" "secrets_manager_read" {
  name        = "${var.service_name}-read-secrets"
  description = ""

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:${var.realm}/${var.deployment_environment}/${var.service_name}-*"
        ]
      }
    ]
  })
}

# Attach the policy to a role
resource "aws_iam_role_policy_attachment" "secrets_manager_read_attachment" {
  role       = aws_iam_role.execution.name
  policy_arn = aws_iam_policy.secrets_manager_read.arn
}
