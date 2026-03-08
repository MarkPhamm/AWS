# aws_iam_mwaa.tf - IAM execution role for MWAA
#
# This is the role that MWAA itself assumes when it runs.
# It's separate from the GitHub Actions role (aws_iam_role.tf).
#
# GitHub Actions role = "who can deploy TO MWAA"
# MWAA execution role = "what can MWAA do once it's running"


# ─── 1. The Role (with trust policy) ──────────────────────────────────
#
# Trust policy: "Only the MWAA service and Airflow service can assume this role"
#
# Two principals:
#   - airflow.amazonaws.com      = the MWAA service itself
#   - airflow-env.amazonaws.com  = the Airflow environment running inside MWAA

resource "aws_iam_role" "mwaa_execution" {
  name = "${var.project_name}-mwaa-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "airflow.amazonaws.com",
            "airflow-env.amazonaws.com"
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-mwaa-execution-role"
    Environment = var.environment
  }
}


# ─── 2. Permissions Policy ────────────────────────────────────────────
#
# What MWAA is allowed to do. Each statement grants a specific set of permissions.

resource "aws_iam_role_policy" "mwaa_execution" {
  name = "mwaa-execution-permissions"
  role = aws_iam_role.mwaa_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      # --- S3: Read DAGs, requirements, plugins from the MWAA bucket ---
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject*",
          "s3:GetBucket*",
          "s3:List*"
        ]
        Resource = [
          aws_s3_bucket.mwaa.arn,
          "${aws_s3_bucket.mwaa.arn}/*"
        ]
        # ↑ Two ARNs: bucket-level (for ListBucket) and object-level (for GetObject)
      },

      # --- CloudWatch Logs: Write Airflow logs ---
      # MWAA writes scheduler, worker, and web server logs to CloudWatch.
      # The log group name follows the pattern: airflow-{environment-name}-*
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:CreateLogGroup",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:GetLogRecord",
          "logs:GetLogGroupFields",
          "logs:GetQueryResults"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:airflow-*"
      },

      # --- CloudWatch Logs: Describe (needed to check if log groups exist) ---
      {
        Effect   = "Allow"
        Action   = "logs:DescribeLogGroups"
        Resource = "*"
        # ↑ DescribeLogGroups can't be scoped to a specific resource
      },

      # --- SQS: MWAA uses SQS internally for the Celery task queue ---
      # Celery is how Airflow distributes tasks to workers.
      # MWAA creates and manages these queues automatically.
      {
        Effect = "Allow"
        Action = [
          "sqs:ChangeMessageVisibility",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage",
          "sqs:SendMessage"
        ]
        Resource = "arn:aws:sqs:${var.aws_region}:*:airflow-celery-*"
      },

      # --- KMS: For encryption at rest ---
      # MWAA encrypts data using AWS KMS (Key Management Service).
      # Even if you don't specify a custom key, MWAA uses the default AWS key.
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey*",
          "kms:Encrypt"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "kms:ViaService" = "sqs.${var.aws_region}.amazonaws.com"
          }
        }
        # ↑ Condition: Only allow KMS actions when called through SQS
        #   This limits the encryption permissions to just what MWAA needs
      }
    ]
  })
}
