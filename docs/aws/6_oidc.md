# OIDC (OpenID Connect)

## What is OIDC?

OIDC is a protocol that lets one service verify the identity of a user or system from another service — without sharing passwords or access keys.

In our case: GitHub Actions proves its identity to AWS, and AWS gives it temporary credentials.

### The Problem OIDC Solves

Without OIDC, you'd store AWS access keys as GitHub secrets:

```text
❌  GitHub Secrets → AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY
    - Long-lived credentials (never expire)
    - Stored in GitHub (what if GitHub is compromised?)
    - Must manually rotate
```

With OIDC:

```text
✅  GitHub Actions → "Here's my identity token" → AWS → "OK, here are temporary credentials"
    - No stored secrets
    - Credentials expire in 1 hour
    - AWS verifies GitHub's identity cryptographically
```

### How It Works

```text
1. GitHub Actions runs your workflow
2. GitHub generates a signed JWT token (identity proof)
3. Workflow sends the token to AWS STS (Security Token Service)
4. AWS checks: "Is this token from GitHub? Is it the right repo?"
5. AWS returns temporary credentials (valid ~1 hour)
6. Workflow uses those credentials to access S3, MWAA, etc.
```

### Key Concepts

| Concept | What it is | Example |
| ------- | ---------- | ------- |
| **Identity Provider** | The service issuing identity tokens | GitHub (`token.actions.githubusercontent.com`) |
| **JWT Token** | A signed identity proof | Contains repo name, branch, workflow info |
| **STS** | AWS Security Token Service | Exchanges tokens for temporary credentials |
| **Thumbprint** | Fingerprint of the provider's SSL cert | Verifies the token really came from GitHub |
| **Audience** | Who the token is intended for | `sts.amazonaws.com` |

### Trust Chain

```text
GitHub (identity provider)
  │
  ├── Signs a JWT: "This is repo MarkPhamm/airflow_mwaa_CICD, branch main"
  │
  └──→ AWS OIDC Provider (trusts GitHub's signing key)
         │
         └──→ IAM Role (trust policy: "allow this repo to assume me")
                │
                └──→ Temporary credentials (1 hour, limited permissions)
```

## How We Use OIDC

GitHub Actions CI/CD pipeline assumes an IAM role via OIDC to deploy DAGs to S3.

```yaml
# In deploy.yml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::203110101827:role/github-actions-deploy
    aws-region: us-east-1
```

No AWS keys stored in GitHub. The role's trust policy restricts access to a specific repo.

## Terraform Resources

| Resource | Purpose |
| ---------- | --------- |
| `aws_iam_openid_connect_provider` | Register GitHub as a trusted identity provider |
| `aws_iam_role` (with OIDC trust policy) | Role that GitHub Actions can assume |

## Cost

OIDC and STS are completely free.
