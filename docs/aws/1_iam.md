# IAM (Identity and Access Management)

## What is IAM?

IAM controls **who** can do **what** in your AWS account. It's the security system that manages authentication (who are you?) and authorization (what can you do?).

### Key Concepts

| Concept | What it is | Example |
| ------- | ---------- | ------- |
| **User** | A person or application with credentials | `minh-admin` |
| **Group** | A collection of users sharing permissions | `Admins`, `Developers` |
| **Role** | A temporary identity that services/users can assume | `mwaa-execution-role` |
| **Policy** | A JSON document defining permissions | "Allow S3 read access" |

### Users vs Roles

| | User | Role |
|---|------|------|
| Has credentials? | Yes (password, access keys) | No (temporary credentials) |
| Who uses it? | People, long-lived applications | AWS services, temporary access |
| Duration | Permanent | Temporary (expires) |
| Example | Your admin user | MWAA execution role, GitHub Actions role |

**Best practice**: Use roles wherever possible. Roles use temporary credentials that auto-expire, which is more secure than permanent access keys.

### Policies

A policy is a JSON document that says what actions are allowed or denied on what resources.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::my-bucket/*"
    }
  ]
}
```

Key fields:

| Field | Meaning | Values |
|-------|---------|--------|
| `Effect` | Allow or deny | `Allow`, `Deny` |
| `Action` | What API calls | `s3:GetObject`, `ec2:*`, `*` |
| `Resource` | Which resources | ARN, `*` (all) |
| `Principal` | Who (in trust policies) | Service, account, user |

### Trust Policy vs Permission Policy

Every role has two types of policies:

- **Trust policy**: Who can **assume** (use) this role?
- **Permission policy**: What can this role **do** once assumed?

```text
Trust policy:       "GitHub Actions can assume this role"
Permission policy:  "This role can read/write to S3"
```

### ARN (Amazon Resource Name)

Every AWS resource has a unique identifier called an ARN:

```text
arn:aws:s3:::my-bucket
arn:aws:iam::203110101827:role/mwaa-execution-role
arn:aws:ec2:us-east-1:203110101827:instance/i-09c4229a205018058
```

Format: `arn:aws:<service>:<region>:<account-id>:<resource>`

## How We Use IAM

| Role | Who assumes it | What it can do |
|------|---------------|----------------|
| `github-actions-deploy` | GitHub Actions (via OIDC) | Sync DAGs to S3, update MWAA |
| `mwaa-execution-role` | MWAA service | Read S3, write CloudWatch logs, use SQS |

## Terraform Resources

| Resource | Purpose |
|----------|---------|
| `aws_iam_role` | Create the role with a trust policy |
| `aws_iam_role_policy` | Attach inline permissions to the role |
| `aws_iam_policy` | Create a standalone reusable policy |
| `aws_iam_role_policy_attachment` | Attach a standalone policy to a role |

## Cost

IAM is completely free. No limits on users, roles, groups, or policies.
