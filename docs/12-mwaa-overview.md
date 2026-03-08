# 12 - MWAA Overview

## What is MWAA?

MWAA stands for **Managed Workflows for Apache Airflow**. It's AWS's managed version of Apache Airflow.

Without MWAA, running Airflow means:

- Setting up a server
- Installing Airflow and all its dependencies
- Managing the database (Airflow metadata)
- Handling the web server, scheduler, and workers
- Keeping everything updated and secure
- Scaling when you need more workers

MWAA does all of this for you. You just provide:

1. **DAGs** (your workflow code) in S3
2. **requirements.txt** (Python packages) in S3
3. **plugins.zip** (custom Airflow plugins) in S3
4. A **VPC** with private subnets for it to run in

AWS handles the rest -- provisioning, patching, scaling, and monitoring.

## How MWAA connects to everything

Here's how all the pieces we've built fit together:

```
You push code to GitHub
        |
        v
GitHub Actions (CI/CD)
        |
        | (assumes IAM role via OIDC)
        v
S3 Bucket (airflow-mwaa-203110101827)
   +-- dags/              --> synced by CI/CD
   +-- requirements.txt   --> uploaded by CI/CD
   +-- plugins.zip        --> uploaded by CI/CD
        |
        | (MWAA reads from S3)
        v
MWAA Environment (runs inside VPC)
   +-- Scheduler  (decides when to run DAGs)
   +-- Workers    (actually runs the tasks)
   +-- Web Server (the Airflow UI you see in browser)
```

Flow:

1. You merge a PR in GitHub
2. GitHub Actions runs `deploy.yml`
3. It assumes the IAM role via OIDC (no stored secrets)
4. It syncs DAGs to S3, uploads requirements.txt and plugins.zip
5. It calls `aws mwaa update-environment` to tell MWAA to pick up changes
6. MWAA reads from S3 and updates itself

## MWAA environment classes

MWAA comes in three sizes:

| Class | Scheduler | Workers | Cost/hr |
|-------|-----------|---------|---------|
| `mw1.small` | 1 (2 vCPU, 2 GB) | 1-5 (1 vCPU, 1 GB each) | ~$0.049 |
| `mw1.medium` | 1 (2 vCPU, 4 GB) | 1-10 (2 vCPU, 2 GB each) | ~$0.098 |
| `mw1.large` | 1 (4 vCPU, 8 GB) | 1-20 (4 vCPU, 4 GB each) | ~$0.196 |

We'll use `mw1.small` -- it's the cheapest and more than enough for learning.

The workers auto-scale: MWAA starts with 1 worker and adds more if your DAGs need parallel tasks. For `mw1.small`, it can scale up to 5 workers.

## MWAA execution role

MWAA needs its own IAM role (separate from the GitHub Actions role). This role gives MWAA permission to:

- **Read S3**: Pull DAGs, requirements.txt, and plugins.zip from your bucket
- **Write S3**: Some Airflow operations may write to S3
- **CloudWatch Logs**: Write Airflow logs (scheduler, worker, web server logs)
- **SQS**: MWAA uses SQS internally for the Celery task queue
- **KMS**: For encryption (optional, but AWS may use default keys)

This is the role that MWAA **assumes when it runs**. It's like giving Airflow its own AWS credentials so it can do its job.

## Web server access

MWAA's Airflow web UI (where you see your DAGs, trigger runs, check logs) can be accessed in two ways:

| Mode | Who can access | How |
|------|---------------|-----|
| `PUBLIC_ONLY` | Anyone with the URL + IAM permissions | Through the internet |
| `PRIVATE_ONLY` | Only from within the VPC | Need a VPN or bastion host |

We'll use `PUBLIC_ONLY` for learning -- it's simpler. Don't worry, it's still secured by IAM. You need AWS credentials to access it, not just the URL.

## MWAA Airflow versions

MWAA supports specific Airflow versions. As of 2024, the latest is **2.10.4**. We'll use this version.

Each version determines:

- Which Python version is used
- Which Airflow features are available
- Which provider packages are pre-installed

## What we'll create in Terraform

| Resource | File | Purpose |
|----------|------|---------|
| VPC | `aws_vpc.tf` | Private network for MWAA |
| Subnets (4) | `aws_vpc.tf` | 2 public + 2 private, in 2 AZs |
| Internet Gateway | `aws_vpc.tf` | VPC's door to the internet |
| NAT Gateway | `aws_vpc.tf` | Private subnet outbound internet access |
| Elastic IP | `aws_vpc.tf` | Static IP for the NAT gateway |
| Route Tables | `aws_vpc.tf` | Traffic routing rules |
| Security Group | `aws_security_group.tf` | Firewall for MWAA |
| IAM Execution Role | `aws_iam_mwaa.tf` | Permissions MWAA needs to run |
| MWAA Environment | `aws_mwaa.tf` | The actual Airflow instance |

Total new resources: ~15 (VPC setup is the bulk of it).

## Cost summary

| Resource | Cost |
|----------|------|
| MWAA mw1.small | ~$0.049/hr |
| NAT Gateway | ~$0.045/hr |
| Elastic IP (while attached) | Free |
| VPC, subnets, IGW, routes | Free |
| Security group | Free |
| **Total** | **~$0.094/hr = ~$2.26/day** |

Remember: run `terraform destroy` when you're done testing to stop all charges.
