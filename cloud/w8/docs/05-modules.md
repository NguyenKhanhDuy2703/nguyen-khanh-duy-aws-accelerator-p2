# 05 — Modules

> Modules là cách đóng gói và tái sử dụng code Terraform — tương đương functions trong lập trình.

---

## Tại sao cần Modules?

Không có modules, một project lớn trở thành một file `main.tf` khổng lồ với hàng nghìn dòng. Khó đọc, khó test, không tái sử dụng được.

Modules cho phép:

- **Đóng gói** logic phức tạp (VPC với subnets, route tables, NAT gateway) thành một "hộp đen"
- **Tái sử dụng** cùng pattern ở nhiều môi trường hoặc projects
- **Versioning** — pinned module version giúp thay đổi có kiểm soát
- **Phân công** — team infra viết modules, team app dùng

---

## Root Module vs Child Module

**Root module** là thư mục bạn chạy `terraform apply` — là "entry point".

**Child module** là module được gọi từ root (hoặc từ module khác).

```
my-project/           ← Root module
├── main.tf
├── variables.tf
├── outputs.tf
└── modules/          ← Child modules (local)
    ├── vpc/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── web-server/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

---

## Cấu trúc một Module

Một module tốt có ít nhất 3 files:

**`variables.tf`** — Inputs của module (parameters)

```hcl
# modules/vpc/variables.tf

variable "vpc_cidr" {
  description = "CIDR block cho VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List CIDR cho public subnets"
  type        = list(string)
}

variable "environment" {
  description = "Tên môi trường (dev/staging/prod)"
  type        = string
}
```

**`main.tf`** — Logic chính

```hcl
# modules/vpc/main.tf

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  }
}

resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.environment}-public-${count.index + 1}"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}
```

**`outputs.tf`** — Outputs để module cha sử dụng

```hcl
# modules/vpc/outputs.tf

output "vpc_id" {
  description = "ID của VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List IDs của public subnets"
  value       = aws_subnet.public[*].id
}
```

---

## Gọi Module từ Root

```hcl
# main.tf (root module)

module "vpc" {
  source = "./modules/vpc"  # local path

  # Truyền vào các variables của module
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  environment         = "production"
}

# Dùng output của module
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  # Tham chiếu output từ module
  subnet_id = module.vpc.public_subnet_ids[0]
}
```

---

## Module Sources — Lấy Module từ đâu?

### Local path

```hcl
module "vpc" {
  source = "./modules/vpc"
}
```

### Terraform Registry (phổ biến nhất)

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.4.0"

  name = "my-vpc"
  cidr = "10.0.0.0/16"
  azs  = ["ap-southeast-1a", "ap-southeast-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.10.0/24", "10.0.20.0/24"]
}
```

Module `terraform-aws-modules/vpc/aws` là một trong những module AWS phổ biến nhất — đã được community test kỹ, production-ready.

### Git repository

```hcl
module "vpc" {
  source = "git::https://github.com/my-company/terraform-modules.git//vpc?ref=v1.2.0"
}
```

### S3 / GCS

```hcl
module "vpc" {
  source  = "s3::https://s3.amazonaws.com/my-bucket/modules/vpc.zip"
}
```

---

## Versioning Modules

Luôn pin version khi dùng registry modules:

```hcl
# BAD — version không cố định, có thể break khi module update
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
}

# GOOD — version cố định
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.4.0"  # hoặc "~> 5.4" cho patch updates
}
```

---

## Module Registry Phổ biến

[terraform-aws-modules](https://github.com/terraform-aws-modules) là collection module AWS chất lượng cao nhất:

- `terraform-aws-modules/vpc/aws` — VPC, subnets, routing
- `terraform-aws-modules/eks/aws` — Kubernetes cluster
- `terraform-aws-modules/rds/aws` — RDS database
- `terraform-aws-modules/s3-bucket/aws` — S3 với best practices
- `terraform-aws-modules/iam/aws` — IAM roles, policies
- `terraform-aws-modules/alb/aws` — Application Load Balancer

```bash
# Sau khi thêm module, luôn chạy lại init
terraform init
```

---

## Patterns Nâng Cao

### Module composition — Modules gọi modules

```hcl
# modules/web-app/main.tf — module dùng module khác
module "vpc" {
  source = "../vpc"
  # ...
}

module "alb" {
  source     = "../alb"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnet_ids
}
```

### Conditional module creation

```hcl
module "monitoring" {
  count  = var.enable_monitoring ? 1 : 0
  source = "./modules/monitoring"
}
```

---

## Khi nào nên tạo Module?

Tạo module khi:

- Cùng một pattern xuất hiện ≥ 2 lần trong codebase
- Muốn encapsulate complexity (VPC với đầy đủ routing, security groups)
- Cần versioning và release cycle riêng

Không cần module khi:

- Code chỉ dùng một lần
- Quá đơn giản (chỉ 1–2 resources)

---

## Kiểm tra hiểu biết

1. Root module và child module khác nhau thế nào?
2. Tại sao cần pin version khi dùng registry module?
3. Sau khi thêm module source mới, cần chạy lệnh gì?

---

**Tiếp theo:** [06-best-practices.md](./06-best-practices.md) — Cấu trúc project, naming, secrets và CI/CD.
