# 06 - IAM Fundamentals

IAM = Identity and Access Management.

It's the system that controls **who** can do **what** in your AWS account.

## Why do we need IAM?

Right now your AWS account has two ways to access it:

1. **Root user** (you, logging into the console with email + password)
2. **`terraform-admin` IAM user** (your CLI, using access keys)

But your CI/CD pipeline (GitHub Actions) also needs access. It needs to:

- Upload files to your S3 bucket (`aws s3 sync`, `aws s3 cp`)
- Read S3 object versions (`aws s3api head-object`)
- Update MWAA environment (`aws mwaa update-environment`)
- Check MWAA status (`aws mwaa get-environment`)

You can't give GitHub your root password or your `terraform-admin` keys. That would be
a huge security risk. Instead, you create an **IAM role** that GitHub Actions can
temporarily "become" using OIDC (we'll cover that in doc 07).

## The 3 building blocks of IAM

### 1. Users

A **user** = a person or program that has long-term credentials (username/password or access keys).

You already have one: `terraform-admin`. That user has access keys that your CLI uses.

**Problem with users for CI/CD**: You'd have to store the access keys as GitHub secrets.
If they leak, anyone can use them forever (until you rotate them). They're like a
permanent house key.

### 2. Roles

A **role** = a temporary identity that someone can "assume" (put on, like a costume).

Think of it this way:

| Concept | Analogy |
| ------- | ------- |
| User | Your driver's license - it's always you |
| Role | A visitor badge - anyone approved can wear it temporarily |

When GitHub Actions "assumes" a role:

1. AWS gives it temporary credentials (like a visitor badge with an expiry time)
2. Those credentials last 1 hour by default
3. When the job finishes, the credentials expire automatically
4. No permanent keys to leak

**This is why we use roles for CI/CD, not users.**

### 3. Policies

A **policy** = a document that says "what actions are allowed on what resources".

It's written in JSON and looks like this (don't worry about memorizing the syntax):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::airflow-mwaa-203110101827/*"
    }
  ]
}
```

Breaking it down:

| Field | What it means | Example |
| ----- | ------------- | ------- |
| `Effect` | Allow or Deny | `"Allow"` |
| `Action` | What API calls are permitted | `"s3:PutObject"` = upload a file |
| `Resource` | Which specific resource(s) | Your S3 bucket ARN |

**Policies don't do anything on their own.** You have to **attach** them to a user or role.

```text
Policy: "Can read/write to S3 bucket"
    │
    └── attached to ──→ Role: "github-actions-deploy"
                            │
                            └── assumed by ──→ GitHub Actions
```

## How the 3 pieces work together

Here's the full picture for your CI/CD:

```text
GitHub Actions (deploy.yml)
    │
    │ "I want to deploy to AWS"
    │
    ▼
IAM Role: "github-actions-deploy"
    │
    │ Has two things attached:
    │
    ├── Trust Policy (WHO can assume this role)
    │   └── "Only GitHub Actions from repo minhpham-pham/airflow_mwaa"
    │
    └── Permissions Policy (WHAT the role can do)
        └── "Can upload to S3, update MWAA"
```

### Trust policy vs permissions policy

Every role has TWO types of policies:

| Policy type | Question it answers | Example |
| ----------- | ------------------- | ------- |
| **Trust policy** | WHO can assume (wear) this role? | "GitHub Actions from my repo" |
| **Permissions policy** | WHAT can this role do once assumed? | "Upload files to S3" |

Think of it like a costume at a theme park:

- **Trust policy** = "Only employees can wear the mascot costume"
- **Permissions policy** = "The mascot can walk in the park and take photos" (but can't go into the kitchen)

## What we already have vs what we need

| What | Status | Notes |
| ---- | ------ | ----- |
| Root user | Exists | You, in the console |
| `terraform-admin` user | Exists | CLI access with permanent keys |
| IAM role for GitHub Actions | **Need to create** | Temporary access for CI/CD |
| OIDC provider | **Need to create** | Tells AWS to trust GitHub's identity tokens |
| Permissions policy for the role | **Need to create** | Allows S3 + MWAA actions |

## IAM is free

IAM doesn't cost anything. You can create as many users, roles, and policies as you
want at no charge. It's a control plane service, not a resource that runs.

## Key terms recap

| Term | One-line definition |
| ---- | ------------------- |
| **IAM** | Identity and Access Management - controls who can do what |
| **User** | Permanent identity with long-term credentials (keys or password) |
| **Role** | Temporary identity anyone approved can "assume" |
| **Policy** | A JSON document that defines allowed/denied actions |
| **Trust policy** | Defines WHO can assume a role |
| **Permissions policy** | Defines WHAT a role (or user) can do |
| **Assume a role** | To temporarily "become" that role and get its permissions |
| **ARN** | Amazon Resource Name - unique ID for any AWS resource |
