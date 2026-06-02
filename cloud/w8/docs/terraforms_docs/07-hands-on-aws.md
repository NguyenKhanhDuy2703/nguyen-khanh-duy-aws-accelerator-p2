# 07 — Hands-on: VPC + EC2 + S3 trên AWS

> Lab thực hành đầy đủ — tạo một web server đơn giản với hạ tầng production-ready.

---

## Mục tiêu

Cuối lab này bạn sẽ tạo được:

```
Internet
    │
    ▼
Internet Gateway
    │
    ▼
Public Subnet (10.0.1.0/24)
    │
    ▼
EC2 Instance (Nginx)  ←→  Security Group (port 80, 22)
    │
    ▼
S3 Bucket (static assets)
```

---

## Chuẩn bị

```bash
# Cấu trúc thư mục
mkdir terraform-aws-lab && cd terraform-aws-lab
touch versions.tf providers.tf main.tf variables.tf outputs.tf
touch terraform.tfvars
```

---

## Bước 1 — Khai báo Provider và Versions

```hcl
# versions.tf
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

```hcl
# providers.tf
provider "aws" {
  region = var.aws_region
}
```

---

## Bước 2 — Variables

```hcl
# variables.tf
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Tên project, dùng làm prefix cho resource names"
  type        = string
}

variable "environment" {
  description = "Môi trường: dev, staging, production"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block cho VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR cho public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "your_ip" {
  description = "IP của bạn để whitelist SSH (format: x.x.x.x/32)"
  type        = string
}
```

```hcl
# terraform.tfvars
project_name = "mylab"
environment  = "dev"
your_ip      = "1.2.3.4/32"  # Thay bằng IP thật: curl ifconfig.me
```

---

## Bước 3 — VPC và Networking

```hcl
# main.tf — phần VPC

# Lấy danh sách AZs của region
data "aws_availability_zones" "available" {
  state = "available"
}

# Lấy AMI Amazon Linux 2 mới nhất
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpc"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-igw"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true  # EC2 trong subnet này tự lấy public IP

  tags = {
    Name = "${var.project_name}-${var.environment}-public-subnet"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-public-rt"
  }
}

# Associate Route Table với Subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
```

---

## Bước 4 — Security Group

```hcl
# main.tf — phần Security Group

resource "aws_security_group" "web_server" {
  name        = "${var.project_name}-${var.environment}-web-sg"
  description = "Security group cho web server"
  vpc_id      = aws_vpc.main.id

  # SSH — chỉ từ IP của bạn
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.your_ip]
    description = "SSH from my IP"
  }

  # HTTP — mở cho tất cả
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from anywhere"
  }

  # Outbound — cho phép tất cả
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-web-sg"
  }
}
```

---

## Bước 5 — EC2 Instance

```hcl
# main.tf — phần EC2

resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_server.id]

  # Script chạy lúc khởi động — cài Nginx
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y nginx
    systemctl start nginx
    systemctl enable nginx
    echo "<h1>Hello from Terraform! Environment: ${var.environment}</h1>" > /usr/share/nginx/html/index.html
  EOF

  tags = {
    Name        = "${var.project_name}-${var.environment}-web-server"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
```

---

## Bước 6 — S3 Bucket

```hcl
# main.tf — phần S3

resource "aws_s3_bucket" "assets" {
  # Tên bucket phải unique globally
  bucket = "${var.project_name}-${var.environment}-assets-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "Static assets"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Random suffix cho bucket name để tránh conflict
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Bật versioning
resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Block public access (best practice)
resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

Thêm `random` provider vào `versions.tf`:

```hcl
required_providers {
  aws = {
    source  = "hashicorp/aws"
    version = "~> 5.0"
  }
  random = {
    source  = "hashicorp/random"
    version = "~> 3.0"
  }
}
```

---

## Bước 7 — Outputs

```hcl
# outputs.tf

output "web_server_public_ip" {
  description = "Public IP của web server"
  value       = aws_instance.web_server.public_ip
}

output "web_server_url" {
  description = "URL truy cập web server"
  value       = "http://${aws_instance.web_server.public_ip}"
}

output "s3_bucket_name" {
  description = "Tên S3 bucket"
  value       = aws_s3_bucket.assets.id
}

output "vpc_id" {
  description = "ID của VPC"
  value       = aws_vpc.main.id
}
```

---

## Chạy Lab

```bash
# 1. Init
terraform init

# 2. Validate
terraform validate

# 3. Plan — đọc kỹ output
terraform plan

# 4. Apply
terraform apply

# 5. Kiểm tra
# Sau khi apply xong, copy web_server_url từ output và mở trong browser
curl $(terraform output -raw web_server_url)

# 6. Dọn dẹp (quan trọng — tránh phát sinh phí)
terraform destroy
```

---

## Troubleshooting Thường Gặp

**Lỗi credentials:**
```
Error: No valid credential sources found for AWS Provider
```
→ Chạy `aws configure` hoặc set `AWS_ACCESS_KEY_ID` và `AWS_SECRET_ACCESS_KEY`.

**Lỗi AMI không tìm thấy:**
→ AMI ID khác nhau theo region. Dùng `data "aws_ami"` thay vì hardcode.

**EC2 tạo xong nhưng web không load:**
→ Nginx cần 1-2 phút để start. Kiểm tra security group đã mở port 80 chưa.

**Lỗi bucket name đã tồn tại:**
→ S3 bucket name unique globally. Dùng `random_id` như ví dụ trên.

---

## Bài tập mở rộng

Sau khi hoàn thành lab cơ bản, thử thêm:

1. **Tạo thêm private subnet** và NAT Gateway
2. **Thêm Application Load Balancer** trước EC2
3. **Dùng Auto Scaling Group** thay vì một EC2 đơn lẻ
4. **Tách code thành modules** theo cấu trúc đã học ở file 05
5. **Thêm remote backend** S3 + DynamoDB theo hướng dẫn file 04

---

## Tổng kết Learning Path

Bạn đã hoàn thành:

- [x] Hiểu IaC và vị trí của Terraform
- [x] Viết được HCL — resources, variables, outputs, modules
- [x] Nắm vững workflow Init/Plan/Apply/Destroy
- [x] Quản lý state đúng cách với remote backend
- [x] Tái sử dụng code với modules
- [x] Áp dụng best practices
- [x] Thực hành tạo hạ tầng thật trên AWS

**Bước tiếp theo:**
- Đọc [Terraform: Up & Running](https://www.oreilly.com/library/view/terraform-up-and/9781098116736/) của Yevgeniy Brikman
- Thực hành với [HashiCorp Learn](https://developer.hashicorp.com/terraform/tutorials)
- Xem series của [Nghĩa Huỳnh](https://kkloudtarus.net/en/blog/series/terraform-from-basics-to-production) để hiểu production patterns