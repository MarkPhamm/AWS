# 08 - Terraform OIDC Provider Syntax Breakdown

This is a line-by-line breakdown of `terraform/aws_iam_oidc.tf`.

## What this file creates

One resource: an OIDC Provider that tells AWS "I trust tokens from GitHub Actions".

You only need one of these per GitHub, even if you have 10 repos deploying to AWS.
It's like registering GitHub as a trusted ID card issuer - you do it once.

## The resource

```hcl
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = ["ffffffffffffffffffffffffffffffffffffffff"]

  tags = {
    Name        = "github-oidc-provider"
    Environment = var.environment
  }
}
```

## Breaking it down

**Line: `resource "aws_iam_openid_connect_provider" "github"`**

- `"aws_iam_openid_connect_provider"` = the resource type
  - `aws_iam` = it's an IAM resource
  - `openid_connect_provider` = specifically an OIDC provider
- `"github"` = our label. We reference it elsewhere as `aws_iam_openid_connect_provider.github`

**Line: `url = "https://token.actions.githubusercontent.com"`**

- This is GitHub's OIDC endpoint - the URL where GitHub publishes its public keys
- AWS goes to this URL to download the keys it needs to verify JWT signatures
- Every identity provider has a URL like this. For example:
  - GitHub Actions: `https://token.actions.githubusercontent.com`
  - Google: `https://accounts.google.com`
  - GitLab: `https://gitlab.com`
- This is a fixed value from GitHub - you don't make it up

**Line: `client_id_list = ["sts.amazonaws.com"]`**

- `client_id_list` = a list of "audiences" (who the token is intended for)
- `["sts.amazonaws.com"]` = a list with one item: AWS STS
- STS = Security Token Service (the AWS service that exchanges JWT tokens for credentials)
- This must match the `aud` (audience) field in the JWT token that GitHub generates
- The `[ ]` brackets make it a list - this is Terraform's list syntax (like Python's `[ ]`)

**Line: `thumbprint_list = ["ffffffffffffffffffffffffffffffffffffffff"]`**

- A thumbprint = a fingerprint of GitHub's SSL certificate
- Historically, AWS used this to verify the HTTPS connection to GitHub
- AWS now verifies through the OIDC protocol itself, so this is just a placeholder
- `"fff...fff"` (40 f's) = a dummy value that AWS accepts for GitHub's OIDC provider
- The string is 40 characters because it's a SHA-1 hash (always 40 hex characters)

## New syntax in this file

### Lists

```hcl
client_id_list = ["sts.amazonaws.com"]
```

- `[ ]` = a list (array). Like Python's `["item1", "item2"]`
- This list has just one item, but you could have multiple:

```hcl
client_id_list = ["sts.amazonaws.com", "another-audience"]
```

We saw lists briefly in the cheat sheet (doc 05). This is the first time we use one
in actual code.

## How this connects to the other files

```text
aws_iam_oidc.tf (this file)
    │
    │  aws_iam_openid_connect_provider.github.arn
    │  (the role references this provider's ARN)
    │
    ▼
aws_iam_role.tf
    │
    │  The role's trust policy says:
    │  "Allow the OIDC provider (Federated = ...github.arn) to assume this role"
    │
    ▼
GitHub Actions can now assume the role
```

The IAM role in `aws_iam_role.tf` uses `aws_iam_openid_connect_provider.github.arn`
in its trust policy. This creates a dependency - Terraform knows to create the OIDC
provider first, then the role.
