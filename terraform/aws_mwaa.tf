# aws_mwaa.tf - The MWAA (Managed Workflows for Apache Airflow) environment
#
# This is the actual Airflow instance. It pulls DAGs, requirements, and plugins
# from the S3 bucket and runs them inside the private subnets we created.


resource "aws_mwaa_environment" "this" {
  name = var.mwaa_environment_name
  # ↑ The name you see in the AWS console and use in CLI commands
  #   e.g., aws mwaa get-environment --name my-mwaa-environment

  # --- Airflow version ---
  airflow_version = "2.10.4"
  # ↑ Latest supported version. Determines Python version and available features.

  # --- IAM execution role ---
  execution_role_arn = aws_iam_role.mwaa_execution.arn
  # ↑ The role MWAA assumes to read S3, write logs, use SQS, etc.
  #   Defined in aws_iam_mwaa.tf

  # --- S3 paths ---
  source_bucket_arn = aws_s3_bucket.mwaa.arn
  dag_s3_path       = "dags"
  # ↑ MWAA looks for DAG files in s3://bucket-name/dags/

  requirements_s3_path = "requirements.txt"
  # ↑ Python packages to install: s3://bucket-name/requirements.txt

  plugins_s3_path = "plugins.zip"
  # ↑ Custom Airflow plugins: s3://bucket-name/plugins.zip

  # --- Environment size ---
  environment_class = "mw1.small"
  # ↑ Smallest (cheapest) option: ~$0.049/hr
  #   1 scheduler (2 vCPU, 2 GB), 1-5 workers (1 vCPU, 1 GB each)

  max_workers = 1
  min_workers = 1
  # ↑ Keep workers fixed at 1 to minimize cost.
  #   Default for mw1.small is min=1, max=5 (auto-scaling).
  #   For learning, 1 worker is enough.

  # --- Web server access ---
  webserver_access_mode = "PUBLIC_ONLY"
  # ↑ The Airflow UI is accessible from the internet (still requires IAM auth).
  #   The alternative is PRIVATE_ONLY (only from within the VPC).

  # --- Networking ---
  network_configuration {
    security_group_ids = [aws_security_group.mwaa.id]
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]
    # ↑ MWAA runs in the 2 PRIVATE subnets (not public).
    #   It needs exactly 2 subnets in different AZs.
  }

  # --- Logging ---
  # Each MWAA component can log to CloudWatch.
  # We enable all of them at INFO level so you can debug issues.
  logging_configuration {
    dag_processing_logs {
      enabled   = true
      log_level = "INFO"
    }
    scheduler_logs {
      enabled   = true
      log_level = "INFO"
    }
    task_logs {
      enabled   = true
      log_level = "INFO"
    }
    webserver_logs {
      enabled   = true
      log_level = "INFO"
    }
    worker_logs {
      enabled   = true
      log_level = "INFO"
    }
  }

  tags = {
    Name        = var.mwaa_environment_name
    Environment = var.environment
  }
}
