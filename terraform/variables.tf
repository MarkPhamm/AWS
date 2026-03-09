# variables.tf - Input values that can change without editing the main code
#
# Think of variables like function parameters:
#   - You define them here (name, type, default value)
#   - You use them in other files with var.variable_name
#   - You can override them without changing any code

variable "project_name" {
  description = "General project name for shared resources (VPC, EC2, etc.)"
  type        = string
  default     = "aws-learning"
}

variable "mwaa_project_name" {
  description = "Project name for MWAA-specific resources (S3, IAM role, security group)"
  type        = string
  default     = "airflow-mwaa"
}

variable "environment" {
  description = "Which environment is this? (learning, dev, prod)"
  type        = string
  default     = "learning"
}

variable "aws_account_id" {
  description = "Your AWS account ID (12 digits) - used to make resource names globally unique"
  type        = string
  default     = "203110101827"
}

variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "github_repo" {
  description = "GitHub repo that is allowed to assume the deploy role (format: owner/repo-name)"
  type        = string
  default     = "MarkPhamm/airflow_mwaa_CICD"
}

variable "ec2_public_key" {
  description = "Public key for SSH access to EC2 (run: ssh-keygen -t ed25519 -f ~/.ssh/aws-ec2-key, then paste the .pub content here)"
  type        = string
  default     = ""
}

variable "mwaa_environment_name" {
  description = "Name of the MWAA environment (must match MWAA_NAME in deploy.yml)"
  type        = string
  default     = "mwaa-environment"
}
