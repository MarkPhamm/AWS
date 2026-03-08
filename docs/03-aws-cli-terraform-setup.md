# 03 - AWS CLI & Terraform Setup (macOS)

## Prerequisites

- Homebrew installed (`/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`)

## Install / Update AWS CLI

```bash
brew install awscli
# or update existing
brew upgrade awscli
```

Verify:

```bash
aws --version
```

## Install / Update Terraform

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
# or update existing
brew upgrade hashicorp/tap/terraform
```

Verify:

```bash
terraform version
```

## Configure AWS CLI with Named Profile

We use a **named profile** instead of the default profile to keep things organized
and avoid conflicts with other AWS credentials.

```bash
aws configure --profile terraform-admin
```

It will prompt for:

1. **AWS Access Key ID** → paste from IAM
2. **AWS Secret Access Key** → paste from IAM
3. **Default region name** → `us-east-1`
4. **Default output format** → `json`

## Verify Connection

```bash
aws sts get-caller-identity --profile terraform-admin
```

Expected output:

```json
{
    "UserId": "AIDA...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/terraform-admin"
}
```

### What is an ARN?

ARN = **Amazon Resource Name**. It's a unique address for anything in AWS
(a user, a bucket, a role, etc.) - like a mailing address for AWS resources.

```text
arn:aws:iam::123456789012:user/terraform-admin
│   │   │    │            │
│   │   │    │            └─ resource type / name
│   │   │    └─ your AWS account ID (12 digits)
│   │   └─ the AWS service (iam, s3, ec2, etc.)
│   └─ which cloud (always "aws")
└─ prefix (always "arn")
```

More ARN examples:

- S3 bucket: `arn:aws:s3:::my-bucket`
- IAM role: `arn:aws:iam::123456789012:role/mwaa-deploy-role`
- EC2 instance: `arn:aws:ec2:us-east-1:123456789012:instance/i-1234567890`

You'll see ARNs everywhere - whenever AWS asks "who or what?", the answer is an ARN.

## How Terraform Uses This Profile

In your Terraform provider block, reference the profile:

```hcl
provider "aws" {
  region  = "us-east-1"
  profile = "terraform-admin"
}
```

## Safety Tips

- Never commit access keys to git (add `.env` and credential files to `.gitignore`)
- Rotate access keys periodically (Actions → Deactivate → Create new)
- Delete keys you're not using
