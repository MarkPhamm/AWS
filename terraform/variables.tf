# variables.tf - Input values that can change without editing the main code
#
# Think of variables like function parameters:
#   - You define them here (name, type, default value)
#   - You use them in other files with var.variable_name
#   - You can override them without changing any code

variable "project_name" {
  description = "A name to tag all resources with, so you know what they belong to"
  type        = string # Can be: string, number, bool, list, map
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
