# 07 - OIDC for GitHub Actions

OIDC = OpenID Connect. It's a standard protocol for proving identity.

## What problem does OIDC solve?

Without OIDC, you'd need to store AWS access keys as GitHub secrets:

```text
The old way (insecure):

1. Create an IAM user with access keys
2. Copy the keys into GitHub repo → Settings → Secrets
3. GitHub Actions reads the secrets and uses them to call AWS

Problems:
- Keys are permanent (never expire unless you rotate them manually)
- If someone leaks the keys, they have full access until you notice
- You have to remember to rotate keys periodically
- Keys are stored in GitHub's systems (another attack surface)
```

With OIDC, there are **no keys stored anywhere**:

```text
The OIDC way (secure):

1. GitHub Actions says "I am a workflow running in repo X, branch Y"
2. GitHub signs this claim with a cryptographic token (like a digital signature)
3. AWS checks the signature and says "yep, this is really GitHub"
4. AWS gives temporary credentials (expire in 1 hour)
5. GitHub Actions uses those credentials to deploy

No permanent keys. Nothing stored. Nothing to leak.
```

## How OIDC works (step by step)

Think of it like getting into a secure building using your company badge:

```text
Step 1: GitHub Actions starts running your deploy.yml
        └── "I need AWS access"

Step 2: GitHub generates a JWT token (a signed identity card)
        └── The token says: "I am a workflow from repo MarkPhamm/airflow_mwaa_CICD (your repo name),
            running on branch main, triggered by a push"
        └── GitHub cryptographically signs it (like a tamper-proof seal)

Step 3: GitHub Actions sends this token to AWS
        └── "Here's my ID card, can I assume the role?"

Step 4: AWS checks with the OIDC Provider
        └── The OIDC Provider we create in AWS knows GitHub's public keys
        └── It verifies: "This signature is real, this token came from GitHub"

Step 5: AWS checks the trust policy on the IAM role
        └── "Is this repo allowed to assume this role?"
        └── Trust policy says: "Only allow repo MarkPhamm/airflow_mwaa_CICD (your repo name) on branch main"
        └── Match! Allow it.

Step 6: AWS gives temporary credentials
        └── Access key + secret key + session token
        └── Expires in 1 hour (default)

Step 7: GitHub Actions uses those credentials to deploy
        └── aws s3 sync, aws mwaa update-environment, etc.
```

### What is a JWT?

JWT = JSON Web Token (pronounced "jot").

Think of it like an ID card, but digital. A physical ID card has your name, photo,
and a hologram stamp that proves it's not fake. A JWT works the same way:

- **Your info** = JSON data (name, repo, branch, etc.)
- **The hologram** = a cryptographic signature (proves GitHub created it, not an imposter)

The actual token is a long encoded string like:

```text
eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJyZXBvOm1pbmhwaGFtL2FpcmZsb3dfbXdhYSIsImlzcyI6Imh0dHBz...
```

That looks like gibberish, but it's just Base64-encoded JSON (a way to convert
JSON into a URL-safe string). Anyone can decode and READ it, but nobody can
MODIFY it without breaking the signature. That's the point - it's tamper-proof,
not secret.

Decoded, it contains:

```json
{
  "iss": "https://token.actions.githubusercontent.com",
  "sub": "repo:MarkPhamm/airflow_mwaa_CICD (your repo name):ref:refs/heads/main",
  "aud": "sts.amazonaws.com",
  "exp": 1234567890
}
```

| Field | What it means |
| ----- | ------------- |
| `iss` | **Issuer** - who created this token ("GitHub Actions") |
| `sub` | **Subject** - which repo and branch this is from |
| `aud` | **Audience** - who this token is intended for ("AWS STS") |
| `exp` | **Expiry** - when this token stops being valid |

AWS uses the `sub` field to check against the trust policy. That's how it knows
which repo is trying to assume the role.

## What we need to create in AWS

Here's the full picture of what we'll build with Terraform:

| Resource | Why |
| -------- | --- |
| **OIDC Provider** | Tells AWS "trust GitHub as an identity provider" |
| **IAM Role** | The temporary identity GitHub Actions will assume |
| **Permissions Policy** | Attached to the role - allows S3 + MWAA actions |
| **Trust Policy** | Built into the role - says "only GitHub from my repo can assume this" |

### How they connect

```text
GitHub Actions pushes code
    │
    ▼
OIDC Provider (verifies "yes, this is really GitHub")
    │
    ▼
IAM Role (trust policy says "allow this specific repo")
    │
    ▼
Permissions Policy (allows s3:PutObject, mwaa:UpdateEnvironment, etc.)
    │
    ▼
Deploys to your S3 bucket
```

Your existing `terraform-admin` user stays as-is - that's just for your local
CLI/Terraform work.

## Where this shows up in deploy.yml

In your `airflow_mwaa` project's deploy.yml, this is the step that uses OIDC:

```yaml
permissions:
  id-token: write    # ← Allows the workflow to request a JWT token from GitHub
  contents: read     # ← Allows checking out the code

steps:
  - name: Configure AWS credentials (OIDC)
    uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::123456789012:role/mwaa-deploy-role
      #               ↑ This is the IAM role ARN we'll create with Terraform
      aws-region: us-east-1
```

The `aws-actions/configure-aws-credentials` action does all the OIDC magic for you:

1. Gets a JWT token from GitHub
2. Sends it to AWS
3. Receives temporary credentials
4. Sets them as environment variables so `aws` CLI commands work

You don't have to write any OIDC code yourself - just create the right AWS resources.

## Why OIDC is better than access keys

| | Access keys (old way) | OIDC (our way) |
| - | --------------------- | --------------- |
| **Credentials** | Permanent until rotated | Temporary (1 hour) |
| **Storage** | Stored in GitHub secrets | Not stored anywhere |
| **If leaked** | Full access until you notice | Already expired |
| **Rotation** | Manual, easy to forget | Automatic, every run |
| **Scope** | Hard to limit per-workflow | Can limit to specific repo + branch |
| **Cost** | Free | Free |

## Key terms recap

| Term | One-line definition |
| ---- | ------------------- |
| **OIDC** | OpenID Connect - a protocol for proving identity without passwords/keys |
| **JWT** | JSON Web Token - a signed identity card that says who you are |
| **STS** | Security Token Service - the AWS service that exchanges JWT for temporary credentials |
| **Assume role** | The act of exchanging a JWT for temporary credentials tied to a role |
| **OIDC Provider** | An AWS resource that says "I trust tokens from this issuer (GitHub)" |
| **Thumbprint** | A fingerprint of GitHub's SSL certificate - AWS uses it to verify the connection |
