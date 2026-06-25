# ResourceDestroyer — Cloud Custodian + Terraform

Automated AWS resource lifecycle management. Marks untagged resources for deletion, sends notifications, and cleans them up after a grace period. Built with Cloud Custodian policies deployed as Lambda functions via Terraform.

---

## How It Works

Every resource type follows a 3-step lifecycle:

1. **Mark** — daily Lambda scans for resources missing a `keep` tag. Marks them with `maid_status` and sends a 30-day warning email.
2. **Warn** — daily Lambda checks for resources 1 day from deletion (`skew: 1`) and sends a final warning email.
3. **Cleanup** — daily Lambda deletes marked resources and sends a post-deletion confirmation email.

Notifications flow through SQS → `c7n-mailer` Lambda → SES.

---

## Repository Layout

```
ResourceDestroyer/
├── environment/
│   └── pocgob/
│       ├── main.tf           # provider, backend, module wiring
│       ├── variables.tf
│       └── outputs.tf
├── modules/
│   ├── iam/                  # 3 least-privilege roles
│   ├── lambda/               # renders + deploys custodian policies
│   └── notifications/        # SNS topic + SQS queue
├── policies/
│   ├── resources/            # one .yml per resource type (source of truth)
│   │   ├── ec2.yml
│   │   ├── rds.yml
│   │   ├── s3.yml
│   │   └── ...               # 19 files total
│   └── mailer.yml            # c7n-mailer config template
└── scripts/
    └── cleanup-custodian.sh  # one-shot migration / pre-apply cleanup
```

---

## Modules

### `modules/iam`

Creates **three least-privilege IAM roles**. One role per phase:

| Role | Permissions |
|---|---|
| `custodian-mark-role` | Read + tag only (`Describe*`, `CreateTags`, `ListTags`). `sqs:SendMessage` scoped to the mailer queue ARN. |
| `custodian-cleanup-role` | Destructive actions only (`TerminateInstances`, `DeleteBucket`, etc.). Explicit `Deny` on the Terraform state S3 bucket. |
| `custodian-mailer-role` | `sqs:ReceiveMessage/DeleteMessage/GetQueueAttributes` scoped to queue ARN. `ses:SendEmail` + `ses:SendRawEmail`. |

No role can delete itself. `iam:DeleteRole` removed from all runtime roles.

**Inputs:** `project`, `environment`, `sqs_queue_arn`, `terraform_state_bucket`
**Outputs:** `mark_role_arn`, `cleanup_role_arn`, `mailer_role_arn` (+ `_name` variants)

---

### `modules/notifications`

Creates the SNS topic and SQS queue used for all policy notifications and mailer processing. SNS → SQS subscription and queue policy are wired automatically.

**Outputs:** `sns_topic_arn`, `sqs_queue_url`, `sqs_queue_arn`

---

### `modules/lambda`

Renders and deploys all Cloud Custodian policies. On every `terraform apply`:

1. **`custodian_gc`** — scans AWS for `custodian-*` Lambdas and EventBridge rules not present in the current policy set and deletes them. Prevents stale Lambdas accumulating after renames or removals.
2. **`custodian_deploy`** — renders each `.yml` in `policies/resources/` (substitutes `MARK_ROLE_ARN`, `CLEANUP_ROLE_ARN`, `ALERT_EMAIL`, `SQS_QUEUE_URL`, `MAILER_ROLE_ARN`) and runs `custodian run` per file.
3. **`mailer_deploy`** — runs `c7n-mailer --config rendered_mailer.yml --update-lambda` to keep the mailer Lambda in sync.

**Inputs:** `policy_dir`, `mark_role_arn`, `cleanup_role_arn`, `mailer_role_arn`, `sqs_queue_url`, `sns_topic_arn`, `alert_email`, `sender_email`, `mailer_template_path`, `aws_region`, `custodian_bin`

---

## Policy Files (`policies/resources/`)

One file per AWS resource type. Each file contains exactly 3 policies:

```
client-<resource>-inventory-mark            # MARK_ROLE_ARN  — tag + 30-day notify
client-<resource>-inventory-notify-warning  # MARK_ROLE_ARN  — skew:1 final warning
client-<resource>-inventory-cleanup         # CLEANUP_ROLE_ARN — delete + post-notify
```

**To add a new resource type:** create `policies/resources/<resource>.yml` following the same 3-policy pattern and run `terraform apply`. The module picks it up automatically via `fileset()`.

**To disable a resource type:** delete or rename its `.yml` file. `custodian_gc` removes the orphaned Lambdas on next apply.

**Covered resources:** `ec2`, `ebs`, `ebs-snapshot`, `ami`, `eks`, `asg`, `elbv2`, `elbv2-targetgroup`, `eni`, `elastic-ip`, `igw`, `nat`, `subnet`, `sg`, `cwlogs`, `rds`, `rds-snapshot`, `rds-subnet-group`, `s3`

---

## scripts/cleanup-custodian.sh

One-shot script for migrating from an old policy set or recovering from a broken state. Deletes all `custodian-*` Lambdas and EventBridge rules in a region, then re-deploys the `c7n-mailer` Lambda.

```bash
# dry-run first
./scripts/cleanup-custodian.sh --region us-east-1 --dry-run

# execute
./scripts/cleanup-custodian.sh --region us-east-1
```

Requires: `aws` CLI, `python3`, `c7n-mailer`. The `rendered_mailer.yml` must exist (run `terraform apply` first).

---

## First Deploy

```bash
# 1. Install dependencies
pip install c7n c7n-mailer

# 2. Configure variables
cp terraform.tfvarsexample environment/pocgob/terraform.tfvars
# edit terraform.tfvars: profile, alert_email, sender_email

# 3. Deploy infrastructure
cd environment/pocgob
terraform init
terraform apply
```

Terraform will: create IAM roles → create SNS/SQS → render policies → GC stale Lambdas → deploy 57 custodian Lambdas → deploy c7n-mailer Lambda.

---

## Tagging Resources to Exclude

Any AWS resource tagged with `keep = true` is excluded from all policies and will never be marked or deleted.

```bash
aws ec2 create-tags --resources i-1234567890abcdef0 --tags Key=keep,Value=true
```

---

## Useful Commands

```bash
# Re-deploy mailer Lambda manually
c7n-mailer --config modules/lambda/rendered_mailer.yml --update-lambda

# Run mailer locally (process SQS queue and send emails)
c7n-mailer --config modules/lambda/rendered_mailer.yml --run

# Invoke a policy Lambda manually for testing
aws lambda invoke \
  --function-name custodian-client-ec2-inventory-mark \
  --payload '{"debug": true}' \
  --cli-binary-format raw-in-base64-out \
  --region us-east-1 \
  /tmp/out.json && cat /tmp/out.json
```

