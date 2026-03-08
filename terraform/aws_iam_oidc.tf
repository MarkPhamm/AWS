# aws_iam_oidc.tf - OIDC provider for GitHub Actions
#
# This tells AWS: "I trust tokens issued by GitHub Actions"
#
# You only need ONE OIDC provider per GitHub (even if you have many repos).
# Think of it as registering GitHub as a trusted ID card issuer.
#
# How it works:
#   GitHub Actions (deploy.yml) → sends JWT token → AWS verifies via OIDC Provider
#   → checks trust policy on the role → gives temporary credentials → deploys


# "token.actions.githubusercontent.com" = GitHub's OIDC endpoint (where AWS
# goes to verify that a JWT token is real)

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
  # ↑ The URL where GitHub publishes its public keys
  #   AWS uses these keys to verify JWT signatures

  client_id_list = ["sts.amazonaws.com"]
  # ↑ "sts.amazonaws.com" = the audience (who the token is intended for)
  #   STS = Security Token Service (the AWS service that exchanges tokens for credentials)
  #   This must match the "aud" field in the JWT token GitHub generates

  thumbprint_list = ["ffffffffffffffffffffffffffffffffffffffff"]
  # ↑ A fingerprint of GitHub's SSL certificate
  #   AWS used to require the real thumbprint, but now it verifies through
  #   the OIDC protocol itself. This placeholder value is accepted by AWS
  #   for GitHub's OIDC provider.

  tags = {
    Name        = "github-oidc-provider"
    Environment = var.environment
  }
}
