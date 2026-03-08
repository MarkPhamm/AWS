# 05 - Terraform S3 Syntax Breakdown

This is a line-by-line breakdown of `terraform/aws_s3.tf`.

## The resource block pattern

Every AWS resource in Terraform follows this pattern:

```hcl
resource "RESOURCE_TYPE" "YOUR_LABEL" {
  setting1 = "value"
  setting2 = "value"
}
```

| Part | What it is | Example |
| ---- | ---------- | ------- |
| `resource` | Keyword - tells Terraform "I want to create something" | Always `resource` |
| `RESOURCE_TYPE` | What kind of thing (from AWS plugin docs) | `"aws_s3_bucket"` |
| `YOUR_LABEL` | Your nickname for it (only used in your code) | `"mwaa"` |
| `{ ... }` | The settings for that resource | `bucket = "my-name"` |

The label is NOT the name in AWS. It's just how you refer to it in other Terraform files.
Two different things:

- `"mwaa"` → your label, used in code like `aws_s3_bucket.mwaa.id`
- `bucket = "airflow-mwaa-203110101827"` → the actual name in AWS

## Resource 1: The bucket itself

```hcl
resource "aws_s3_bucket" "mwaa" {
  bucket = "${var.project_name}-${var.aws_account_id}"

  tags = {
    Name        = "${var.project_name}-bucket"
    Environment = var.environment
  }
}
```

### Breaking it down

**Line: `resource "aws_s3_bucket" "mwaa"`**

- `resource` → "I want to create something"
- `"aws_s3_bucket"` → the type. All AWS resources start with `aws_`.
  You find these in the Terraform AWS docs. Common ones:
  - `aws_s3_bucket` → S3 bucket
  - `aws_iam_role` → IAM role
  - `aws_instance` → EC2 virtual server
- `"mwaa"` → your label. Could be anything: `"my_bucket"`, `"data_lake"`, etc.
  You reference it later as `aws_s3_bucket.mwaa`

**Line: `bucket = "${var.project_name}-${var.aws_account_id}"`**

- `bucket` → a setting that `aws_s3_bucket` requires (the bucket name in AWS)
- `"${var.project_name}"` → string interpolation (inserting a variable into a string)
  - `var.` → "get a variable from variables.tf"
  - `project_name` → the variable name
  - `${...}` → "insert this value here" (like Python f-string `f"{project_name}"`)
  - Result: `"airflow-mwaa-203110101827"`

**When do you need `${}` vs not?**

```hcl
# When MIXING variables with text, use "${}"
bucket = "${var.project_name}-${var.aws_account_id}"

# When the value IS the variable (nothing else), no "${}" needed
bucket = var.project_name
```

**Block: `tags = { ... }`**

```hcl
tags = {
  Name        = "${var.project_name}-bucket"
  Environment = var.environment
}
```

- `tags` = a map (key-value pairs, like a Python dictionary)
- Tags are labels you attach to resources. They don't affect how the resource works.
- Useful for:
  - Finding resources in the AWS Console (filter by tag)
  - Billing (see cost per tag)
  - Automation (delete all resources tagged "learning")

## Resource 2: Versioning

```hcl
resource "aws_s3_bucket_versioning" "mwaa" {
  bucket = aws_s3_bucket.mwaa.id

  versioning_configuration {
    status = "Enabled"
  }
}
```

### Breaking it down

**Why is this a separate resource?**

You might expect versioning to be a setting inside `aws_s3_bucket`. But AWS treats
bucket settings as separate API calls, so Terraform mirrors that with separate resources.
This is an AWS/Terraform quirk you'll get used to.

**Line: `bucket = aws_s3_bucket.mwaa.id`**

This is a **reference** to another resource. Let's break it apart:

```text
aws_s3_bucket.mwaa.id
│              │    │
│              │    └─ .id = an attribute (the bucket name, returned by AWS after creation)
│              └─ .mwaa = the label we gave the bucket resource
└─ aws_s3_bucket = the resource type
```

This creates a **dependency**: Terraform knows it must create the bucket FIRST,
then configure versioning. You don't need to tell it the order - it figures it out
from the references.

**Block: `versioning_configuration { ... }`**

A nested block (a block inside a block). Some settings are grouped this way.
`status = "Enabled"` turns versioning on.

## Resource 3: Public access block

```hcl
resource "aws_s3_bucket_public_access_block" "mwaa" {
  bucket = aws_s3_bucket.mwaa.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

### Breaking it down

- Same pattern: separate resource, linked via `bucket = aws_s3_bucket.mwaa.id`
- 4 boolean settings, all set to `true` = "block everything public"
- `true` / `false` = boolean values in Terraform (no quotes needed)

**What's an ACL?**

ACL = Access Control List. An older way to control who can access S3 objects.
AWS recommends using IAM policies instead (which we'll do later).
We block public ACLs here just to be safe.

## How the 3 resources connect

```text
aws_s3_bucket.mwaa
    │
    ├── aws_s3_bucket_versioning.mwaa      (bucket = aws_s3_bucket.mwaa.id)
    │
    └── aws_s3_bucket_public_access_block.mwaa  (bucket = aws_s3_bucket.mwaa.id)
```

Both the versioning and public access block resources point back to the bucket.
Terraform uses these references to:

1. Know the **order** (create bucket first, then the other two)
2. Pass the **bucket name** automatically (you don't hardcode it)

## Quick reference: Terraform syntax cheat sheet

```hcl
# String
name = "hello"

# Number
count = 3

# Boolean
enabled = true

# Variable reference (no quotes!)
region = var.aws_region

# String interpolation (variable inside a string)
name = "${var.project}-bucket"

# Map (key-value pairs, like Python dict)
tags = {
  Name = "my-thing"
  Env  = "learning"
}

# List (array)
cidrs = ["10.0.0.0/16", "10.1.0.0/16"]

# Reference another resource
bucket = aws_s3_bucket.mwaa.id
#        └ type ──────┘ └label┘ └attribute┘

# Nested block
versioning_configuration {
  status = "Enabled"
}
```
