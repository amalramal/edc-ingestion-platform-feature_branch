#
# Configuration for the S3 bucket that SFTPGo uses to store data
#
# ---
resource "aws_s3_bucket" "sftpgo" {
  bucket = "sftpgo-${var.environment}"
  tags = {
    "service" = "sftpgo"
  }
}

resource "aws_iam_policy" "sftpgo_s3_access" {
  name        = "${var.environment}-sftpgo-s3-access-policy"
  description = "Policy to allow SFTPGo S3 bucket access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.sftpgo.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.sftpgo.arn}/*"
        ]
      }
    ]
  })
  tags = {
    "service" = "sftpgo"
  }
}
