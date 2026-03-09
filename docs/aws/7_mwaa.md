# MWAA (Managed Workflows for Apache Airflow)

## What is MWAA?

MWAA is AWS's managed version of Apache Airflow. You provide DAGs in S3, and AWS handles the infrastructure — scheduler, workers, web server, database, scaling, and patching.

### Key Concepts

| Concept | What it is | Example |
| ------- | ---------- | ------- |
| **Environment** | A running Airflow instance | `mwaa-environment` |
| **DAG** | A workflow definition (Python file) | `dags/my_etl.py` |
| **Scheduler** | Decides when to run DAGs | 1 per environment |
| **Worker** | Executes the actual tasks | Auto-scales 1-5 (mw1.small) |
| **Web server** | The Airflow UI in your browser | Public or private access |
| **Execution role** | IAM role MWAA uses to access AWS services | S3, CloudWatch, SQS |

### Environment Classes

| Class | Scheduler | Workers | Cost/hr |
|-------|-----------|---------|---------|
| `mw1.small` | 1 (2 vCPU, 2 GB) | 1-5 (1 vCPU, 1 GB each) | ~$0.049 |
| `mw1.medium` | 1 (2 vCPU, 4 GB) | 1-10 (2 vCPU, 2 GB each) | ~$0.098 |
| `mw1.large` | 1 (4 vCPU, 8 GB) | 1-20 (4 vCPU, 4 GB each) | ~$0.196 |

### Web Server Access

| Mode | Who can access | How |
|------|---------------|-----|
| `PUBLIC_ONLY` | Anyone with the URL + IAM credentials | Through the internet |
| `PRIVATE_ONLY` | Only from within the VPC | Need VPN or bastion host |

### What MWAA Needs

```text
S3 Bucket (DAGs, requirements.txt, plugins.zip)
    │
    └──→ MWAA Environment
           ├── Lives in: 2 private subnets (different AZs)
           ├── Internet via: NAT Gateway
           ├── Firewall: Security group (self-referencing)
           ├── Permissions: IAM execution role
           └── Reads DAGs from: S3 bucket
```

Required infrastructure:
- **VPC** with 2 private subnets in different AZs
- **NAT Gateway** for outbound internet (pip install, AWS APIs)
- **Security group** with self-referencing inbound (components talk to each other)
- **IAM execution role** with access to S3, CloudWatch Logs, SQS
- **S3 bucket** with versioning enabled

## How We Use MWAA

```text
GitHub → CI/CD (OIDC) → S3 Bucket → MWAA reads DAGs
```

1. Push code to GitHub
2. GitHub Actions syncs DAGs to S3 (via OIDC, no stored keys)
3. MWAA picks up changes from S3 automatically

## Terraform Resources

| Resource | File | Purpose |
|----------|------|---------|
| `aws_mwaa_environment` | `aws_mwaa.tf` | The Airflow environment |
| `aws_iam_role.mwaa_execution` | `aws_iam_mwaa.tf` | Execution role |
| `aws_iam_role_policy.mwaa_policy` | `aws_iam_mwaa.tf` | Permissions for the role |
| `aws_security_group.mwaa` | `aws_security_group.tf` | Firewall rules |

## Cost

| Resource | Cost |
|----------|------|
| MWAA mw1.small | ~$0.049/hr (~$35/month) |
| NAT Gateway | ~$0.045/hr (~$32/month) |
| S3 storage | ~$0 (DAGs are tiny) |
| **Total** | **~$0.094/hr = ~$2.26/day = ~$67/month** |

No free tier. Run `terraform destroy` when not using it.
