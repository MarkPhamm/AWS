# aws_iam_role.tf - IAM role + permissions policy for GitHub Actions CI/CD
#
# This file creates:
#   1. IAM Role          → the temporary identity GitHub Actions will assume
#   2. IAM Policy        → what the role is allowed to do (S3 + MWAA access)


# ─── 1. IAM Role ─────────────────────────────────────────────────────
#
# This is the role that GitHub Actions will "assume" (temporarily become).
#
# Every role has TWO parts:
#   - assume_role_policy = the TRUST policy (WHO can assume this role)
#   - We attach a separate PERMISSIONS policy below (WHAT the role can do)

resource "aws_iam_role" "github_actions_deploy" {
  name = "github-actions-deploy"
  # ↑ The name of the role in AWS. This is what shows up in the console
  #   and in the ARN: arn:aws:iam::203110101827:role/github-actions-deploy

  # TRUST POLICY: Who can assume this role?
  # This is JSON that says: "Only GitHub Actions from my specific repo can assume this role"
  #
  # jsonencode() = a Terraform function that converts HCL (Terraform's language)
  # into JSON format. AWS policies must be JSON, but writing JSON in Terraform
  # is ugly, so jsonencode() lets us write it in a nicer format.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    # ↑ The policy language version. Always "2012-10-17" (it's not a date you choose,
    #   it's the version of AWS's policy language. There's only this one.)

    Statement = [
      {
        Effect = "Allow"
        # ↑ "Allow" this action (the alternative is "Deny")

        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
          # ↑ WHO is allowed? The OIDC provider we created in aws_iam_oidc.tf.
          #   "Federated" = an external identity provider (not an AWS user/role)
          #   This reference also creates a dependency: Terraform creates the
          #   OIDC provider first, then this role.
        }

        Action = "sts:AssumeRoleWithWebIdentity"
        # ↑ The specific API call that exchanges a JWT for temporary credentials
        #   "sts" = Security Token Service
        #   "AssumeRoleWithWebIdentity" = "I have a web identity token (JWT), give me credentials"

        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            # ↑ The token's audience must be "sts.amazonaws.com"
            #   This matches what we set in client_id_list in aws_iam_oidc.tf
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
            # ↑ The token's subject must match your repo
            #   "repo:MarkPhamm/airflow_mwaa_CICD:*" = any branch/event from this repo
            #   The * wildcard means it works for pushes to main, PRs, etc.
            #   If you wanted to restrict to only main branch, you'd use:
            #   "repo:MarkPhamm/airflow_mwaa_CICD:ref:refs/heads/main"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "github-actions-deploy"
    Environment = var.environment
  }
}


# ─── 2. Permissions Policy ───────────────────────────────────────────
#
# This defines WHAT the role can do once assumed.
# We give it permission to:
#   - Read/write to our S3 bucket (for syncing DAGs and requirements.txt)
#   - Update and check MWAA environment status
#
# This is a separate resource that gets "attached" to the role.

resource "aws_iam_role_policy" "github_actions_deploy" {
  name = "mwaa-deploy-permissions"
  role = aws_iam_role.github_actions_deploy.id
  # ↑ Attach this policy to the role we created above

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Statement 1: S3 bucket-level actions (list objects in the bucket)
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
          # ↑ Allows listing what's in the bucket (needed by "aws s3 sync --delete"
          #   to know which files to remove)
        ]
        Resource = aws_s3_bucket.mwaa.arn
        # ↑ The bucket itself: "arn:aws:s3:::airflow-mwaa-203110101827"
        #   Note: bucket-level actions use the bucket ARN (no /* at the end)
      },
      # Statement 2: S3 object-level actions (read/write files inside the bucket)
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          # ↑ Read a file from S3
          "s3:PutObject",
          # ↑ Upload a file to S3
          "s3:DeleteObject",
          # ↑ Delete a file from S3 (needed by "aws s3 sync --delete")
          "s3:GetObjectVersion"
          # ↑ Read a specific version of a file (needed to get requirements.txt VersionId)
        ]
        Resource = "${aws_s3_bucket.mwaa.arn}/*"
        # ↑ All objects INSIDE the bucket: "arn:aws:s3:::airflow-mwaa-203110101827/*"
        #   The /* means "any file path inside this bucket"
        #   Note: object-level actions need /* at the end (different from bucket-level)
      },
      # Statement 3: S3 version check (for head-object to get VersionId)
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketVersioning"
          # ↑ Check if versioning is enabled on the bucket
          #   Needed by: aws s3api head-object ... --query 'VersionId'
        ]
        Resource = aws_s3_bucket.mwaa.arn
      },
      # Statement 4: MWAA actions (update environment and check status)
      {
        Effect = "Allow"
        Action = [
          "mwaa:UpdateEnvironment",
          # ↑ Update MWAA config (point to new requirements.txt version)
          "mwaa:GetEnvironment"
          # ↑ Check MWAA status (wait for it to become AVAILABLE)
        ]
        Resource = "arn:aws:airflow:us-east-1:${var.aws_account_id}:environment/*"
        # ↑ All MWAA environments in your account
        #   We use * here because the MWAA environment doesn't exist yet
        #   When we create it later, we can tighten this to the specific name
      }
    ]
  })
}
