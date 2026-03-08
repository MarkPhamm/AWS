# aws_s3.tf - S3 bucket for MWAA
#
# This bucket stores:
#   - dags/          → Airflow DAG files (MWAA reads these automatically)
#   - requirements.txt → Python packages for MWAA to install


# ─── 1. Create the bucket ───────────────────────────────────────────
#
# resource "aws_s3_bucket" "mwaa" = "Create an S3 bucket, and I'll call it 'mwaa' in my code"
#
# "aws_s3_bucket" = the resource type (from the AWS provider plugin)
# "mwaa"          = YOUR label for it (used to reference it elsewhere, e.g. aws_s3_bucket.mwaa.id)
#
# bucket = the actual name in AWS (must be globally unique)

resource "aws_s3_bucket" "mwaa" {
  bucket = "${var.project_name}-${var.aws_account_id}"
  # ↑ This becomes: "airflow-mwaa-203110101827"
  #
  # ${var.project_name} = pulls the value from variables.tf → "airflow-mwaa"
  # ${var.aws_account_id} = pulls the value from variables.tf → "203110101827"
  # "${...}" = string interpolation (like f-strings in Python or template literals in JS)

  tags = {
    Name        = "${var.project_name}-bucket"
    Environment = var.environment
    # ↑ Tags are labels you attach to AWS resources
    #   - They don't change how the resource works
    #   - They help you find and filter resources in the console
    #   - They show up in billing so you know what costs what
  }
}


# ─── 2. Enable versioning ──────────────────────────────────────────
#
# Versioning = S3 keeps every version of a file, not just the latest.
# Like git history but for files in S3.
#
# Why we need it:
#   - MWAA requires versioning to track which requirements.txt version to install
#   - Your deploy.yml does: aws s3api head-object ... --query 'VersionId'
#   - Without versioning, that command would fail (no VersionId exists)
#
# This is a SEPARATE resource because AWS treats bucket settings as separate from the bucket itself.
# The "bucket = ..." line links it to the bucket above.

resource "aws_s3_bucket_versioning" "mwaa" {
  bucket = aws_s3_bucket.mwaa.id
  # ↑ "aws_s3_bucket.mwaa.id" = reference to the bucket we created above
  #   format: resource_type.label.attribute
  #   .id = the bucket name (AWS returns this after creating it)

  versioning_configuration {
    status = "Enabled"
  }
}


# ─── 3. Block all public access ────────────────────────────────────
#
# By default S3 buckets are private, but this adds an extra layer of protection.
# It's like putting a padlock on a locked door - belt AND suspenders.
#
# This ensures nobody can accidentally make the bucket or its files public.
# Your DAGs and requirements should never be publicly accessible.

resource "aws_s3_bucket_public_access_block" "mwaa" {
  bucket = aws_s3_bucket.mwaa.id

  block_public_acls       = true # Block public ACLs (access control lists)
  block_public_policy     = true # Block public bucket policies
  ignore_public_acls      = true # Ignore any existing public ACLs
  restrict_public_buckets = true # Restrict public bucket policies
}
