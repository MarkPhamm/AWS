# providers.tf - Tells Terraform WHICH cloud to talk to and HOW to authenticate
#
# "provider" = a plugin that knows how to talk to a specific cloud (AWS, Azure, GCP, etc.)
# We're using the "aws" provider, maintained by HashiCorp.

terraform {
  # required_providers = "I need these plugins installed"
  required_providers {
    aws = {
      source  = "hashicorp/aws" # Where to download the AWS plugin from
      version = "~> 5.0"        # Use version 5.x (the ~> means "any 5.something")
    }
  }

  # Minimum Terraform version needed
  required_version = ">= 1.0"
}

# Configure the AWS provider - tells it which region and credentials to use
provider "aws" {
  region  = "us-east-1"       # N. Virginia - matches your deploy.yml
  profile = "terraform-admin" # The named profile we set up in AWS CLI
}
