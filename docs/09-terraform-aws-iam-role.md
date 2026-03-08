# 09 - Terraform IAM Role Syntax Breakdown

This is a line-by-line breakdown of `terraform/aws_iam_role.tf`.

## What this file creates

Two resources:

1. **IAM Role** - the temporary identity GitHub Actions will "assume"
2. **IAM Role Policy** - the permissions attached to that role (what it can do)

## Resource 1: The IAM Role

```hcl
resource "aws_iam_role" "github_actions_deploy" {
  name = "github-actions-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }

        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
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
```

### Breaking it down

**Line: `resource "aws_iam_role" "github_actions_deploy"`**

- `"aws_iam_role"` = resource type for an IAM role
- `"github_actions_deploy"` = our label (used as `aws_iam_role.github_actions_deploy`)

**Line: `name = "github-actions-deploy"`**

- The actual name of the role in AWS (shows up in the console and in the ARN)
- ARN will be: `arn:aws:iam::203110101827:role/github-actions-deploy`
- This is the name you'd put in deploy.yml's `role-to-assume`

**Block: `assume_role_policy = jsonencode({ ... })`**

This is the **trust policy** - it defines WHO can assume this role.

`jsonencode()` is a Terraform built-in function. AWS policies must be JSON, but
writing raw JSON in Terraform is messy (you'd need escaped quotes everywhere).
`jsonencode()` lets you write it in HCL (Terraform's language) and converts it to
JSON automatically.

```text
Without jsonencode (ugly):
assume_role_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{...}]}"

With jsonencode (clean):
assume_role_policy = jsonencode({
  Version = "2012-10-17"
  Statement = [...]
})
```

**Line: `Version = "2012-10-17"`**

- The version of AWS's policy language
- This is NOT a date you choose - it's always `"2012-10-17"`
- There's only one version. AWS just happened to name it after a date.

**Block: `Statement = [ { ... } ]`**

- A list of rules. Each rule is a `{ }` block inside the `[ ]` list
- We have one rule that says "allow GitHub to assume this role"

**Line: `Effect = "Allow"`**

- Either `"Allow"` or `"Deny"`. We want to allow this action.

**Block: `Principal = { Federated = ... }`**

- `Principal` = WHO is this rule about?
- `Federated` = an external identity provider (not an AWS user/service)
- `aws_iam_openid_connect_provider.github.arn` = reference to the OIDC provider
  we created in `aws_iam_oidc.tf`
- This is the same pattern as `aws_s3_bucket.mwaa.id` - referencing another resource

**Line: `Action = "sts:AssumeRoleWithWebIdentity"`**

- What action is being allowed?
- `sts` = Security Token Service (the AWS service that handles temporary credentials)
- `AssumeRoleWithWebIdentity` = "I have a JWT token, please give me temporary credentials"
- This is the specific API call that the `aws-actions/configure-aws-credentials`
  GitHub Action makes behind the scenes

**Block: `Condition = { ... }`**

Conditions are extra checks. Even if the Principal matches, the conditions must ALSO
pass. Think of it as an "AND" - "Allow this Principal AND only if these conditions
are true."

**`StringEquals` condition:**

```hcl
StringEquals = {
  "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
}
```

- Check the JWT's `aud` (audience) field
- It must exactly equal `"sts.amazonaws.com"`
- This ensures the token was intended for AWS, not some other service

**`StringLike` condition:**

```hcl
StringLike = {
  "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
}
```

- Check the JWT's `sub` (subject) field
- `StringLike` allows wildcards (`*`), unlike `StringEquals`
- `"repo:MarkPhamm/airflow_mwaa_CICD:*"` = any event from this repo
- The `*` matches any branch, tag, or event type
- If you wanted ONLY the main branch: `"repo:MarkPhamm/airflow_mwaa_CICD:ref:refs/heads/main"`

### Why Condition matters

Without the Condition block, ANY GitHub repo could assume your role (as long as
they use GitHub's OIDC). The Condition locks it down to YOUR repo only. This is
critical for security.

## Resource 2: The Permissions Policy

```hcl
resource "aws_iam_role_policy" "github_actions_deploy" {
  name = "mwaa-deploy-permissions"
  role = aws_iam_role.github_actions_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.mwaa.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:GetObjectVersion"]
        Resource = "${aws_s3_bucket.mwaa.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetBucketVersioning"]
        Resource = aws_s3_bucket.mwaa.arn
      },
      {
        Effect   = "Allow"
        Action   = ["mwaa:UpdateEnvironment", "mwaa:GetEnvironment"]
        Resource = "arn:aws:airflow:us-east-1:${var.aws_account_id}:environment/*"
      }
    ]
  })
}
```

### Breaking it down

**Line: `resource "aws_iam_role_policy" "github_actions_deploy"`**

- `"aws_iam_role_policy"` = an inline policy attached directly to a role
- This is different from `aws_iam_policy` (a standalone policy you can reuse).
  Inline policies are simpler when you only need it for one role.

**Line: `role = aws_iam_role.github_actions_deploy.id`**

- Which role to attach this policy to
- References the role we created above (same pattern as `bucket = aws_s3_bucket.mwaa.id`)

**Block: `policy = jsonencode({ ... })`**

- Same as the trust policy - JSON converted from HCL via `jsonencode()`
- But this policy defines WHAT the role can DO, not WHO can assume it

### The 4 statements explained

**Statement 1: S3 bucket-level actions**

```hcl
Action   = ["s3:ListBucket"]
Resource = aws_s3_bucket.mwaa.arn
```

- `s3:ListBucket` = list what files are in the bucket
- Needed by `aws s3 sync --delete` (it needs to see what's in S3 to know what to delete)
- `Resource` = the bucket ARN (no `/*` at the end)
- Bucket-level actions target the bucket itself

**Statement 2: S3 object-level actions**

```hcl
Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:GetObjectVersion"]
Resource = "${aws_s3_bucket.mwaa.arn}/*"
```

- These actions work on files INSIDE the bucket
- `s3:GetObject` = download a file (used by: reading DAGs)
- `s3:PutObject` = upload a file (used by: `aws s3 cp requirements.txt`)
- `s3:DeleteObject` = delete a file (used by: `aws s3 sync --delete`)
- `s3:GetObjectVersion` = read a specific version (used by: getting VersionId)
- `Resource` = bucket ARN + `/*` (the `/*` means "any file path inside")

Why two separate statements for S3? AWS treats the bucket and its contents as
different resources:

```text
arn:aws:s3:::airflow-mwaa-203110101827      ← the bucket itself (ListBucket)
arn:aws:s3:::airflow-mwaa-203110101827/*    ← files inside it (GetObject, PutObject, etc.)
```

**Statement 3: S3 versioning check**

```hcl
Action   = ["s3:GetBucketVersioning"]
Resource = aws_s3_bucket.mwaa.arn
```

- `s3:GetBucketVersioning` = check if versioning is enabled
- Needed by `aws s3api head-object ... --query 'VersionId'`
- This is a bucket-level action (no `/*`)

**Statement 4: MWAA actions**

```hcl
Action   = ["mwaa:UpdateEnvironment", "mwaa:GetEnvironment"]
Resource = "arn:aws:airflow:us-east-1:${var.aws_account_id}:environment/*"
```

- `mwaa:UpdateEnvironment` = update the MWAA config (point to new requirements.txt version)
- `mwaa:GetEnvironment` = check MWAA status (wait for AVAILABLE)
- `Resource` = all MWAA environments in your account
- We use `*` because the MWAA environment doesn't exist yet. When we create it later,
  we can tighten this to the specific environment name.

### Action naming convention

All AWS actions follow this pattern:

```text
service:ActionName
│       │
│       └── What you're doing (PascalCase)
└── Which AWS service
```

Examples:

| Action | Service | What it does |
| ------ | ------- | ------------ |
| `s3:GetObject` | S3 | Download a file |
| `s3:PutObject` | S3 | Upload a file |
| `s3:ListBucket` | S3 | List files in a bucket |
| `mwaa:UpdateEnvironment` | MWAA | Update an Airflow environment |
| `sts:AssumeRoleWithWebIdentity` | STS | Exchange JWT for credentials |
| `iam:CreateRole` | IAM | Create a new role |

## New syntax in this file

### jsonencode()

```hcl
assume_role_policy = jsonencode({
  Version = "2012-10-17"
  Statement = [...]
})
```

- A Terraform built-in function (not specific to AWS)
- Converts HCL maps/lists into JSON strings
- AWS policies require JSON, so you'll see this in every IAM resource

### Inline policy vs standalone policy

```text
aws_iam_role_policy         ← Inline: lives inside the role, can't be reused
aws_iam_policy              ← Standalone: exists on its own, can be attached to multiple roles
aws_iam_role_policy_attachment  ← Connects a standalone policy to a role
```

We used inline (`aws_iam_role_policy`) because this policy is only for this one role.
If you needed the same permissions for multiple roles, you'd use standalone.

## How all the files connect

```text
aws_iam_oidc.tf                          aws_s3.tf
    │                                        │
    │ .arn                                   │ .arn
    ▼                                        ▼
aws_iam_role.tf
    │
    ├── aws_iam_role (trust policy references OIDC provider)
    │
    └── aws_iam_role_policy (permissions reference S3 bucket)
            │
            ▼
        GitHub Actions can: sync to S3, update MWAA
```

Terraform figures out the order automatically from these references:

1. Create S3 bucket (already exists)
2. Create OIDC provider
3. Create IAM role (depends on OIDC provider)
4. Create IAM policy (depends on role and S3 bucket)
