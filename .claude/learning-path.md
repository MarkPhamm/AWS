# Learning Path: AWS + Terraform (Data Engineer Focus)

## Phase 1: Foundations
- [ ] What is cloud computing and why AWS?
- [x] AWS account setup basics (free plan, $100 credits, 185 days remaining)
- [x] **Billing & cost protection** ($10/month budget alert set up)
- [x] What is Infrastructure as Code (IaC) and why Terraform?
- [x] Terraform installation and CLI basics (v1.14.6, terraform init done)
- [x] HCL syntax fundamentals (providers, resources, variables, outputs)

## Phase 2: S3 Bucket (first resource - needed by both CI/CD and MWAA)
- [x] S3 fundamentals - buckets, objects, versioning
- [x] S3 bucket for MWAA with Terraform (bucket: airflow-mwaa-203110101827)
- [ ] S3 bucket policies and IAM permissions

## Phase 3: OIDC + CI/CD (so GitHub Actions can deploy to S3)
- [ ] IAM fundamentals - users, roles, policies
- [ ] What is OIDC (OpenID Connect) and why use it for CI/CD?
- [ ] IAM OIDC Identity Provider for GitHub Actions (Terraform)
- [ ] IAM Role with trust policy for GitHub Actions (Terraform)
- [ ] Testing: GitHub Actions assuming the role and syncing to S3

## Phase 4: MWAA (depends on S3 + networking)
- [ ] MWAA overview - what it is, how it connects to S3
- [ ] VPC, subnets, security groups for MWAA
- [ ] MWAA environment with Terraform
- [ ] End-to-end: CI/CD deploys DAGs to S3 -> MWAA picks them up

## Phase 4: Networking & Compute Basics
- [ ] VPC (Virtual Private Cloud) - networking basics
- [ ] Subnets, route tables, internet gateways
- [ ] Security Groups - firewall rules
- [ ] EC2 basics (useful context, not daily driver for data engineers)

## Phase 5: Data Engineer Extras
- [ ] Terraform state management (local vs remote with S3 backend)
- [ ] Terraform modules (reusable code)
- [ ] RDS / Redshift basics
- [ ] Glue, Athena, Lambda (serverless data processing)
- [ ] CloudWatch (monitoring & logging)
- [ ] Cost management and tagging strategies

## Current Status
- **Current phase**: Not started
- **Last topic covered**: N/A
