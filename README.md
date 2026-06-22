# ResourceDestroyer

Automated AWS resource inventory and lifecycle enforcement using [Cloud Custodian](https://cloudcustodian.io/) deployed via Terraform.

Resources without a `keep` tag enter a **30-day grace period**, then are automatically deleted.

---

## How it works

```
terraform apply
      │
      ├─ module.iam       → IAM role + least-privilege inline policy
      └─ module.lambda    → renders policy.yml → runs `custodian run`
                                │
                                └─ deploys 10 Lambda functions (one per policy)
                                   each triggered by EventBridge on a daily schedule

Daily schedule (per resource type)
  mark job  → scans for resources missing tag:keep → adds mops tag (grace period starts)
  sweep job → scans for resources past grace period → deletes them
```

**Covered resources:** EC2 instances · RDS instances · VPCs · S3 buckets · IAM roles

**Self-protection:** the custodian IAM role is excluded from the IAM sweep at both the policy level and the IAM permission level (`NotResource`).

---

## Prerequisites

| Tool | Min version | Install |
|---|---|---|
| Terraform | 1.5.0 | https://developer.hashicorp.com/terraform/install |
| Python | 3.10+ | https://python.org |
| c7n (Cloud Custodian) | latest | `pip install c7n` |
| AWS CLI | v2 | https://aws.amazon.com/cli/ |

AWS credentials must be configured before running (`aws configure` or environment variables).

---

## Variables

| Variable | Description | Default |
|---|---|---|
| `aws_region` | Region where Lambdas are deployed | `us-east-1` |
| `project` | Project name — used in resource naming and tags | `client-alpha` |
| `environment` | Deployment environment (`dev`, `stage`, `prod`) | `prod` |

Edit `terraform.tfvars` to override defaults:

```hcl
aws_region  = "us-east-1"
project     = "my-project"
environment = "dev"
```

---

## Deploy

```bash
# 1. Install Cloud Custodian
pip install c7n

# 2. Configure AWS credentials
aws configure

# 3. Init and apply
terraform init
terraform apply
```

Terraform will:
1. Create the IAM execution role with scoped permissions.
2. Render `policies/policy.yml` with the real role ARN and role name.
3. Run `custodian run` — this deploys 10 Lambda functions and their EventBridge schedules.

---

## Tagging resources to keep them

Add the `keep` tag to any resource you do **not** want deleted:

```bash
# EC2
aws ec2 create-tags --resources i-0123456789abcdef0 --tags Key=keep,Value=true

# RDS
aws rds add-tags-to-resource \
  --resource-name arn:aws:rds:us-east-1:123456789012:db:my-db \
  --tags Key=keep,Value=true

# S3
aws s3api put-bucket-tagging \
  --bucket my-bucket \
  --tagging 'TagSet=[{Key=keep,Value=true}]'

# VPC
aws ec2 create-tags --resources vpc-0123456789abcdef0 --tags Key=keep,Value=true

# IAM role
aws iam tag-role --role-name my-role --tags Key=keep,Value=true
```

The tag value is irrelevant — only the **presence** of the `keep` key matters.

---

## Grace period

When a resource is found without `keep`, Cloud Custodian writes a `mops` tag:

```
mops = terminate@2026-07-22T00:00:00+00:00
```

The sweep Lambda runs daily and deletes resources whose grace date has passed. To rescue a resource during the grace period, add the `keep` tag before the date in `mops`.

---

## Policies

Defined in `policies/policy.yml`. Each resource type has two policies:

| Policy name | Trigger | Action |
|---|---|---|
| `client-<type>-inventory-mark` | daily | tag resources missing `keep` with 30-day deadline |
| `client-<type>-inventory-cleanup` | daily | delete resources past their deadline |

---

## Outputs

```bash
terraform output custodian_role_arn    # ARN of the Lambda execution role
terraform output custodian_role_name   # Name of the Lambda execution role
terraform output custodian_deploy_id   # Hash of last deployment (changes when policy changes)
```

---

## Destroy

```bash
terraform destroy
```

This removes the IAM role and inline policy. The Lambda functions deployed by `custodian run` are managed outside Terraform state — remove them manually or via the AWS console if needed.

---

## Project structure

```
ResourceDestroyer/
├── main.tf                  # root: provider, module calls
├── variables.tf             # aws_region, project, environment
├── outputs.tf               # role ARN/name, deploy ID
├── terraform.tfvars         # your values
├── modules/
│   ├── iam/
│   │   ├── main.tf          # IAM role + least-privilege inline policy
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── lambda/
│       ├── main.tf          # renders policy YAML, runs custodian run
│       ├── variables.tf
│       └── outputs.tf
└── policies/
    └── policy.yml           # Cloud Custodian policy definitions
```
