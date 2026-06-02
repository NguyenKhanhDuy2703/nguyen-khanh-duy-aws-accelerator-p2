# 06 — Best Practices

> Những nguyên tắc giúp Terraform project của bạn scale được theo thời gian.

---

## Cấu trúc Project

### Cấu trúc đơn giản (small project)

```
project/
├── main.tf
├── variables.tf
├── outputs.tf
├── providers.tf        # provider "aws" {...}
├── versions.tf         # terraform { required_providers {...} }
├── terraform.tfvars    # giá trị thật (gitignored)
└── terraform.tfvars.example  # template, commit vào git
```

### Cấu trúc theo môi trường (production pattern)

```
project/
├── modules/                    # Shared modules
│   ├── vpc/
│   ├── web-server/
│   └── database/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── backend.tf          # backend riêng cho dev
│   ├── staging/
│   │   └── ...
│   └── production/
│       └── ...
└── README.md
```

Mỗi environment có **state riêng**. Không dùng workspace vì workspace dễ nhầm lẫn — bạn phải nhớ đang ở workspace nào.

---

## Naming Conventions

### Tên resources

```hcl
# Format: <project>-<environment>-<component>-<resource_type>
resource "aws_vpc" "main" {
  tags = {
    Name = "myapp-prod-main-vpc"
  }
}

# Trong code Terraform: snake_case, mô tả rõ
resource "aws_security_group" "web_server_sg" { ... }
resource "aws_iam_role"        "ecs_task_execution" { ... }
```

### Tên variables

```hcl
# snake_case, nhóm theo prefix khi liên quan
variable "vpc_cidr"             { ... }
variable "vpc_public_subnets"   { ... }
variable "vpc_private_subnets"  { ... }

variable "rds_instance_class"   { ... }
variable "rds_allocated_storage" { ... }
```

### Tên outputs

```hcl
# Rõ ràng, bao gồm loại resource
output "vpc_id"              { ... }
output "web_server_public_ip" { ... }
output "rds_endpoint"        { ... }
```

---

## Variables Best Practices

### Luôn có description và type

```hcl
# BAD
variable "size" {}

# GOOD
variable "instance_type" {
  description = "EC2 instance type. t3.micro cho dev, t3.large cho prod."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium", "t3.large"], var.instance_type)
    error_message = "Chỉ chấp nhận: t3.micro, t3.small, t3.medium, t3.large."
  }
}
```

### Validation blocks

```hcl
variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment phải là: dev, staging, hoặc production."
  }
}

variable "vpc_cidr" {
  type = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr phải là CIDR block hợp lệ (ví dụ: 10.0.0.0/16)."
  }
}
```

---

## Quản lý Secrets

### Không bao giờ hardcode secrets

```hcl
# BAD — đừng bao giờ làm này
resource "aws_db_instance" "main" {
  password = "super_secret_123"  # ❌ Sẽ lộ trong state và git history
}

# GOOD — dùng variable
variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true  # Terraform sẽ ẩn giá trị trong output
}

resource "aws_db_instance" "main" {
  password = var.db_password
}
```

### Lấy secrets từ AWS Secrets Manager

```hcl
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "production/myapp/db-password"
}

resource "aws_db_instance" "main" {
  password = jsondecode(data.aws_secretsmanager_secret_version.db_password.secret_string)["password"]
}
```

### .gitignore bắt buộc

```gitignore
# Terraform
*.tfstate
*.tfstate.*
*.tfvars          # Chứa real values
!*.tfvars.example # Chỉ commit example files
.terraform/
crash.log
override.tf
override.tf.json
```

---

## Tagging Strategy

Luôn tag resources — giúp tracking cost, ownership, và cleanup:

```hcl
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = "platform-team"
    CostCenter  = "engineering"
  }
}

resource "aws_instance" "web" {
  # ...
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-web"
    Role = "web-server"
  })
}
```

---

## Terraform fmt và validate

Chạy 2 lệnh này trước mọi commit:

```bash
# Format code theo chuẩn HashiCorp
terraform fmt -recursive

# Kiểm tra syntax và internal consistency
terraform validate
```

Tích hợp vào pre-commit hook:

```bash
# .git/hooks/pre-commit
#!/bin/sh
terraform fmt -check -recursive
terraform validate
```

Hoặc dùng [pre-commit framework](https://pre-commit.com) với hooks của [terraform-docs](https://terraform-docs.io).

---

## CI/CD Pipeline

### GitHub Actions example

```yaml
# .github/workflows/terraform.yml
name: Terraform

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  terraform:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.5.7"

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ap-southeast-1

      - name: Terraform Init
        run: terraform init

      - name: Terraform Format Check
        run: terraform fmt -check -recursive

      - name: Terraform Validate
        run: terraform validate

      - name: Terraform Plan
        run: terraform plan -out=tfplan
        if: github.event_name == 'pull_request'

      - name: Terraform Apply
        run: terraform apply -auto-approve tfplan
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
```

---

## Terraform Docs

Tự động generate documentation từ variables và outputs:

```bash
# Cài terraform-docs
brew install terraform-docs

# Generate README cho module
terraform-docs markdown table . > README.md
```

---

## Những điều KHÔNG nên làm

```hcl
# ❌ Không commit terraform.tfstate
# ❌ Không dùng -auto-approve trên production thủ công
# ❌ Không hardcode account IDs, region vào code
# ❌ Không để secrets trong variables.tf default values
# ❌ Không bỏ qua plan output trước khi apply
# ❌ Không sửa state file thủ công bằng text editor
```

---

## Checklist trước khi merge

- [ ] `terraform fmt -check` pass
- [ ] `terraform validate` pass
- [ ] Plan đã được review và không có `destroy` bất ngờ
- [ ] Không có secrets trong code
- [ ] Variables có `description` và `type`
- [ ] Resources có tags đầy đủ
- [ ] README cập nhật nếu cần

---

**Tiếp theo:** [07-hands-on-aws.md](./07-hands-on-aws.md) — Thực hành tạo VPC, EC2, S3 trên AWS.
