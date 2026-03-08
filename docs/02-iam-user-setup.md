# 02 - IAM User Setup for Terraform

## Why Not Use Root?
- Root account has unlimited access to everything (like running as admin)
- Best practice: create a dedicated IAM user for CLI/Terraform work
- Root should only be used for billing and account-level settings

## Create IAM User
1. Go to AWS Console → search "IAM" → click Users → Create user
2. **User name**: `terraform-admin`
3. **Do NOT** check "Provide user access to the AWS Management Console" (CLI-only)
4. Click Next

## Attach Permissions
1. Choose "Attach policies directly"
2. Search and check **`AdministratorAccess`**
3. Click Next → Create user

> Note: AdministratorAccess is broad. Fine for learning, tighten later for production.

## Create Access Key
1. Click on the `terraform-admin` user
2. Go to "Security credentials" tab
3. Scroll to "Access keys" → "Create access key"
4. Choose "Command Line Interface (CLI)"
5. Copy both:
   - **Access Key ID** (starts with `AKIA...`)
   - **Secret Access Key** (shown only once!)
6. Store these securely (password manager, not plain text files)
