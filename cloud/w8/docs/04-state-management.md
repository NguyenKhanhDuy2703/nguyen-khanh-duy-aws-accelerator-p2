# 04 — State Management

> State là "bộ nhớ" của Terraform — hiểu đúng để tránh những lỗi đau đầu nhất.

---

## State file là gì?

Sau khi `terraform apply`, Terraform lưu lại toàn bộ thông tin về resources đã tạo vào file `terraform.tfstate`. File này là JSON và chứa mọi thứ:

```json
{
  "version": 4,
  "terraform_version": "1.5.7",
  "resources": [
    {
      "type": "aws_instance",
      "name": "web_server",
      "instances": [
        {
          "attributes": {
            "id": "i-0abc123def456",
            "public_ip": "54.123.45.67",
            "instance_type": "t3.micro"
          }
        }
      ]
    }
  ]
}
```

### Tại sao cần state?

Terraform không query AWS mỗi lần để biết hạ tầng đang ở trạng thái nào. Thay vào đó, nó:

1. Đọc state file để biết "hiện tại đang có gì"
2. Đọc `.tf` files để biết "muốn có gì"
3. Tính diff → sinh ra plan

Không có state = Terraform không biết resource nào của mình, resource nào của người khác.

---

## Vấn đề với local state

Mặc định, `terraform.tfstate` được lưu **trên máy bạn**. Điều này gây ra:

**Vấn đề 1 — Team không dùng chung được state**
Developer A apply trên máy mình → state ở máy A. Developer B apply trên máy mình → state ở máy B. Kết quả: conflict, duplicate resources.

**Vấn đề 2 — Không có locking**
Hai người apply cùng lúc → state file bị corrupt.

**Vấn đề 3 — State chứa secrets**
State lưu plaintext passwords, API keys. Lưu local rồi commit Git là lộ secrets.

**Giải pháp: Remote Backend**

---

## Remote Backend

Backend là nơi Terraform lưu state. Remote backend giải quyết cả 3 vấn đề trên.

### S3 + DynamoDB (phổ biến nhất cho AWS)

```hcl
# versions.tf
terraform {
  backend "s3" {
    bucket         = "my-company-terraform-state"
    key            = "production/web-app/terraform.tfstate"
    region         = "ap-southeast-1"

    # State locking
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

Cần tạo trước:

- S3 bucket (với versioning bật lên)
- DynamoDB table với primary key `LockID` (String)

```bash
# Tạo S3 bucket
aws s3api create-bucket \
  --bucket my-company-terraform-state \
  --region ap-southeast-1 \
  --create-bucket-configuration LocationConstraint=ap-southeast-1

# Bật versioning
aws s3api put-bucket-versioning \
  --bucket my-company-terraform-state \
  --versioning-configuration Status=Enabled

# Tạo DynamoDB table cho locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-southeast-1
```

### Terraform Cloud (đơn giản nhất)

```hcl
terraform {
  cloud {
    organization = "my-company"

    workspaces {
      name = "web-app-production"
    }
  }
}
```

Terraform Cloud cung cấp state storage, locking, và cả UI miễn phí cho small teams.

---

## State Locking

Khi `terraform apply` đang chạy, Terraform tạo một **lock** để ngăn người khác apply cùng lúc.

```
│ Error: Error acquiring the state lock
│
│ Error message: ConditionalCheckFailedException: The conditional request failed
│ Lock Info:
│   ID:        20060101000000
│   Path:      my-bucket/terraform.tfstate
│   Operation: OperationTypeApply
│   Who:       user@machine
│   Created:   2024-01-15 10:30:00
```

Nếu apply bị crash giữa chừng, lock có thể bị "kẹt". Giải phóng thủ công:

```bash
terraform force-unlock <LOCK_ID>
```

---

## Workspaces — Quản lý nhiều môi trường

Workspaces cho phép dùng cùng code nhưng có state riêng cho mỗi môi trường.

```bash
# Xem workspace hiện tại
terraform workspace show

# Tạo workspace mới
terraform workspace new staging
terraform workspace new production

# Chuyển workspace
terraform workspace select production

# List workspaces
terraform workspace list
```

Trong code, dùng `terraform.workspace` để điều chỉnh theo môi trường:

```hcl
locals {
  instance_type = terraform.workspace == "production" ? "t3.large" : "t3.micro"
}

resource "aws_instance" "web" {
  instance_type = local.instance_type

  tags = {
    Environment = terraform.workspace
  }
}
```

> **Cân nhắc:** Workspaces đơn giản nhưng có giới hạn. Với hạ tầng phức tạp, nhiều team thường dùng **separate directories** cho mỗi môi trường thay vì workspaces (chi tiết ở file 06).

---

## Thao tác State nâng cao

### Xem state

```bash
# List tất cả resources
terraform state list

# Chi tiết một resource
terraform state show aws_instance.web_server
```

### Di chuyển resource trong state

```bash
# Đổi tên resource (không tạo lại resource thật)
terraform state mv aws_instance.web aws_instance.web_server

# Di chuyển sang module
terraform state mv aws_instance.web module.web_server.aws_instance.main
```

### Xóa resource khỏi state (không xóa resource thật)

```bash
# Hữu ích khi muốn "quên" resource mà không destroy nó
terraform state rm aws_instance.old_server
```

### Import resource đã tồn tại

```bash
# Thêm resource đang chạy vào state
terraform import aws_instance.existing i-0abc123def456
```

---

## Bảo mật State

State file chứa **plaintext sensitive data** như passwords, private keys. Bắt buộc phải:

- Không bao giờ commit `terraform.tfstate` vào Git
- Thêm vào `.gitignore`:

```gitignore
# .gitignore
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl    # có thể commit cái này
```

- Dùng S3 backend với encryption (`encrypt = true`)
- Hạn chế IAM access vào S3 bucket chứa state

---

## Kiểm tra hiểu biết

1. Tại sao không nên dùng local state khi làm việc theo team?
2. DynamoDB trong S3 backend đóng vai trò gì?
3. `terraform state rm` và `terraform destroy` khác nhau thế nào?

---

**Tiếp theo:** [05-modules.md](./05-modules.md) — Tái sử dụng code với Modules.
