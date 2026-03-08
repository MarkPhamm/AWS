# AWS

Learning AWS + Terraform from scratch, focused on data engineering.

## Project Structure

```text
terraform/          Terraform configs (infrastructure as code)
docs/               Step-by-step learning guides
docs/aws/           AWS service reference docs
.claude/            Learning path and memory
```

## AWS Resources Created

| Resource | Name | Purpose |
| -------- | ---- | ------- |
| S3 Bucket | `airflow-mwaa-203110101827` | Stores DAGs and requirements.txt for MWAA |
| OIDC Provider | `token.actions.githubusercontent.com` | Lets AWS trust GitHub Actions identity tokens |
| IAM Role | `github-actions-deploy` | Temporary identity for GitHub Actions CI/CD |

### Screenshots

![S3 Bucket](docs/assets/s3-bucket-created.png)
![IAM Roles](docs/assets/roles-created.png)
![OIDC Identity Provider](docs/assets/identity-providers-created.png)

## Docs

1. [AWS Account Setup](docs/01-aws-account-setup.md)
2. [IAM User Setup](docs/02-iam-user-setup.md)
3. [AWS CLI & Terraform Setup](docs/03-aws-cli-terraform-setup.md)
4. [Terraform Basics](docs/04-terraform-basics.md)
5. [Terraform S3 Syntax Breakdown](docs/05-terraform-aws-s3.md)
6. [S3 Reference](docs/aws/s3.md)
7. [IAM Fundamentals](docs/06-iam-fundamentals.md)
8. [OIDC for GitHub Actions](docs/07-oidc-github-actions.md)
9. [Terraform OIDC Provider Breakdown](docs/08-terraform-aws-iam-oidc.md)
10. [Terraform IAM Role Breakdown](docs/09-terraform-aws-iam-role.md)

## Related Project

- [`airflow_mwaa`](../airflow_mwaa) - CI/CD with Airflow on Amazon MWAA (deploys to the S3 bucket above)
