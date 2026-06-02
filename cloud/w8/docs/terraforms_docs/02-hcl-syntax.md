# 02 — HCL Syntax

> HashiCorp Configuration Language — ngôn ngữ khai báo hạ tầng của Terraform.

---

## HCL là gì?

HCL (HashiCorp Configuration Language) được thiết kế để **dễ đọc hơn JSON, mạnh hơn YAML**. Bạn sẽ viết HCL 95% thời gian khi làm việc với Terraform.

File HCL có đuôi `.tf`. Terraform đọc toàn bộ file `.tf` trong thư mục và ghép lại thành một configuration.

---

## Block — Đơn vị cơ bản

Mọi thứ trong Terraform là **block**. Cú pháp tổng quát:

```hcl
<block_type> "<type_label>" "<name_label>" {
  argument = value
}
```

### Các block type quan trọng

**`terraform`** — Cấu hình Terraform engine

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

**`provider`** — Kết nối với cloud provider

```hcl
provider "aws" {
  region = "ap-southeast-1"  # Singapore
}
```

**`resource`** — Tạo một tài nguyên thật (EC2, S3, VPC...)

```hcl
resource "aws_instance" "web_server" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"

  tags = {
    Name = "my-web-server"
  }
}
```

Cú pháp: `resource "<provider_type>" "<local_name>"`. Local name dùng để tham chiếu trong code — không phải tên resource trên AWS.

**`data`** — Đọc thông tin đã tồn tại (không tạo mới)

```hcl
# Lấy thông tin AMI mới nhất của Amazon Linux 2
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}
```

**`variable`** — Khai báo biến đầu vào

```hcl
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}
```

**`output`** — Xuất giá trị sau khi apply

```hcl
output "web_server_ip" {
  description = "Public IP của web server"
  value       = aws_instance.web_server.public_ip
}
```

**`locals`** — Biến nội bộ, tính toán một lần rồi dùng nhiều chỗ

```hcl
locals {
  environment = "production"
  common_tags = {
    Environment = local.environment
    Project     = "my-app"
    ManagedBy   = "terraform"
  }
}
```

---

## Types — Kiểu dữ liệu

```hcl
# String
name = "my-server"

# Number
port = 8080

# Bool
enable_monitoring = true

# List (mảng)
availability_zones = ["ap-southeast-1a", "ap-southeast-1b"]

# Map (object đơn giản)
tags = {
  Name = "web"
  Env  = "prod"
}

# Object (map có schema cố định)
variable "disk_config" {
  type = object({
    size = number
    type = string
  })
  default = {
    size = 20
    type = "gp3"
  }
}
```

---

## References — Tham chiếu giữa các resources

Đây là phần quan trọng nhất — cách các resource "nói chuyện" với nhau.

```hcl
# Tạo VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Tạo Subnet bên trong VPC đó
resource "aws_subnet" "public" {
  # Tham chiếu tới VPC ở trên: <type>.<name>.<attribute>
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
}
```

Terraform tự động suy ra **dependency graph** từ các tham chiếu này — nên `aws_vpc.main` sẽ được tạo trước `aws_subnet.public`.

---

## Expressions — Biểu thức

### String interpolation

```hcl
locals {
  bucket_name = "my-app-${var.environment}-assets"
}
```

### Conditional (ternary)

```hcl
instance_type = var.environment == "production" ? "t3.large" : "t3.micro"
```

### For expressions

```hcl
# Tạo list từ list khác
locals {
  upper_zones = [for az in var.availability_zones : upper(az)]

  # Tạo map
  instance_map = { for inst in var.instances : inst.name => inst.type }
}
```

### `count` và `for_each` — Tạo nhiều resources

```hcl
# Dùng count — tạo 3 instances giống nhau
resource "aws_instance" "worker" {
  count         = 3
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  tags = {
    Name = "worker-${count.index}"
  }
}

# Dùng for_each — tạo từ map/set (tốt hơn count khi items có identity)
variable "servers" {
  default = {
    web = "t3.micro"
    api = "t3.small"
    db  = "t3.medium"
  }
}

resource "aws_instance" "servers" {
  for_each      = var.servers
  ami           = data.aws_ami.amazon_linux.id
  instance_type = each.value  # giá trị của map

  tags = {
    Name = each.key  # key của map: "web", "api", "db"
  }
}
```

> **Nên dùng `for_each` thay `count`** khi items có tên/identity riêng. Lý do: nếu xóa item ở giữa list khi dùng count, Terraform sẽ recreate các item sau nó.

---

## Built-in Functions

Terraform có nhiều hàm built-in hữu ích:

```hcl
# String functions
lower("HELLO")          # → "hello"
upper("hello")          # → "HELLO"
trimspace("  hi  ")     # → "hi"
replace("a-b-c", "-", "_")  # → "a_b_c"

# Collection functions
length(["a", "b", "c"])  # → 3
concat(["a"], ["b", "c"]) # → ["a", "b", "c"]
flatten([[1, 2], [3]])    # → [1, 2, 3]
merge({a=1}, {b=2})       # → {a=1, b=2}

# Encoding
jsonencode({key = "value"})   # → "{\"key\":\"value\"}"
base64encode("hello")          # → "aGVsbG8="

# File
file("./scripts/init.sh")      # đọc nội dung file
templatefile("./tmpl.tpl", { name = "world" })  # render template
```

Xem đầy đủ tại [Built-in Functions Docs](https://developer.hashicorp.com/terraform/language/functions).

---

## Cấu trúc file thường dùng

Một project nhỏ thường có:

```
my-project/
├── main.tf          # Resources chính
├── variables.tf     # Khai báo variables
├── outputs.tf       # Outputs
├── providers.tf     # Provider config
├── versions.tf      # terraform block + required_providers
└── terraform.tfvars # Giá trị thật của variables (không commit)
```

---

## Kiểm tra hiểu biết

1. Sự khác nhau giữa `resource` và `data` block là gì?
2. Khi nào nên dùng `for_each` thay vì `count`?
3. Làm sao Terraform biết resource nào cần tạo trước?

---

**Tiếp theo:** [03-workflow.md](./03-workflow.md) — Vòng đời Init → Plan → Apply → Destroy.
