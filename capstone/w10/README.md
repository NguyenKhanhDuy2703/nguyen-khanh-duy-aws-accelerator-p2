# Capstone W11 — Detect Sensitive Data in S3 with Amazon Macie

## Architecture

```
S3 Bucket (sensitive data uploaded)
        │
        ▼
  Amazon Macie
  (Classification Job — scan S3)
        │
        ▼
  Macie Findings
        │
        ▼
  Amazon EventBridge Rule
  (source: aws.macie)
        │
        ▼
  Amazon SNS Topic
        │
        ▼
  Email Notification (subscriber)
```

## Project Structure

```
capstone/w11/
├── environments/
│   └── dev/
│       ├── backend.tf        # Remote state (S3 + DynamoDB)
│       ├── main.tf           # Module wiring
│       ├── variables.tf      # Input variables
│       ├── outputs.tf        # Outputs
│       └── terraform.tfvars  # Dev values (gitignored secrets)
├── modules/
│   ├── s3/                   # S3 bucket + sample sensitive data upload
│   ├── macie/                # Macie enable + classification job
│   ├── notifications/        # SNS topic + EventBridge rule
│   └── iam/                  # IAM roles for Macie
├── test-data/                # Sample sensitive data files for testing
├── s3-ddb/                   # Remote state bootstrap (S3 + DynamoDB)
└── Makefile
```

## Quick Start

### Step 1 — Bootstrap Remote State (run once)
```bash
make state-apply
```

### Step 2 — Deploy Infrastructure
```bash
make init
make plan
make apply
```

### Step 3 — Trigger Macie Scan
After apply, Macie classification job runs automatically.
Check findings in AWS Console → Macie → Findings.

### Step 4 — Check Email
Confirm the SNS subscription from your email, then wait for Macie findings notification.

### Cleanup
```bash
make destroy
make state-destroy
```

## Variables to customize

| Variable | Description | Default |
|----------|-------------|---------|
| `region` | AWS region | `us-east-1` |
| `owner` | Owner tag | `capstone-w11` |
| `notification_email` | Email for Macie alerts | **(required)** |
| `bucket_name` | S3 bucket to scan | auto-generated |
