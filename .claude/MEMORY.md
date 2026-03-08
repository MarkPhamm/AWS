# AWS + Terraform Learning Project

## Learner Profile
- **Experience level**: Complete beginner - no prior cloud experience
- **Role focus**: Data Engineer
- **Goal**: Learn cloud infrastructure end-to-end with AWS and Terraform
- **Learning style**: Step-by-step, slow pace, make sure every concept is understood before moving on
- **Approach**: Guided hands-on learning

## Priority
- Data engineering AWS services: S3, IAM, MWAA
- OIDC (OpenID Connect) for GitHub Actions CI/CD - needed for airflow_mwaa project
- Related project: `/Users/minh.pham/personal/project/airflow_mwaa` (Airflow MWAA CI/CD)
  - Has deploy.yml using OIDC to assume IAM role for deploying DAGs to S3/MWAA
  - Needs: IAM OIDC identity provider, IAM role with trust policy, S3 bucket

## Teaching Guidelines
- Explain every concept before using it (no assumptions about prior knowledge)
- Use analogies to make cloud concepts relatable
- Always explain the "why" before the "how"
- Break tasks into small, digestible steps
- Verify understanding before moving to the next topic

## Progress Tracker
- See [learning-path.md](./learning-path.md) for curriculum and progress
