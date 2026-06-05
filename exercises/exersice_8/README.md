# Exercise 8 — AWS VPC + EC2 + ALB + Kubernetes (Minikube)

> Deploy một Node.js app lên Kubernetes chạy trên EC2, expose ra Internet qua Application Load Balancer, provisioned hoàn toàn bằng Terraform.

---

## Mục tiêu

| # | Yêu cầu |
|---|---|
| 1 | Provision AWS infrastructure bằng Terraform (VPC, EC2, ALB, S3) |
| 2 | Cài Minikube + Docker trên EC2 qua remote-exec provisioner |
| 3 | Build Docker image từ Node.js app và deploy lên Kubernetes |
| 4 | Expose app ra Internet qua ALB → NodePort → K8s Service → Pod |
| 5 | Quản lý Terraform remote state trên S3 + DynamoDB lock |

---

## Stack

| Layer | Technology |
|---|---|
| IaC | Terraform >= 1.0, AWS Provider ~> 6.0 |
| Cloud | AWS — VPC, EC2, ALB, S3 |
| Container | Docker 28.x |
| Orchestration | Kubernetes 1.35 (Minikube) |
| App | Node.js 20 (Alpine) |
| OS | Ubuntu 20.04 (Focal) — t3.small |

---

## Cấu trúc thư mục

```
exersice_8/
├── Makefile                        ← Entrypoint: init/plan/apply/destroy
├── ARCHITECTURE.md                 ← Sơ đồ kiến trúc đầy đủ
├── README.md                       ← File này
│
├── app/
│   ├── index.js                    ← Node.js HTTP server (port 80)
│   ├── Dockerfile                  ← node:20-alpine, EXPOSE 80
│   └── deployment.yaml             ← K8s Deployment (4 replicas) + NodePort Service
│
├── environments/dev/
│   ├── main.tf                     ← Root module, wire tất cả modules
│   ├── variables.tf                ← Biến cấu hình (region, instance_type...)
│   ├── outputs.tf                  ← alb_dns_link, vpc_id, sg_ec2_id
│   └── backend.tf                  ← Remote state: S3 + DynamoDB
│
├── modules/
│   ├── vpc/                        ← VPC, 2 public + 2 private subnets, IGW
│   ├── security/                   ← SG-ALB (80), SG-EC2 (22, 30080)
│   ├── compute/
│   │   ├── ec2.tf                  ← EC2 + SSH key + remote-exec provisioner
│   │   └── alb.tf                  ← ALB + Target Group + Listener
│   └── storage/                    ← S3 bucket (static assets, versioned)
│
├── s3-ddb/
│   └── main.tf                     ← Bootstrap: tạo S3 + DynamoDB cho remote state
│
└── scripts/
    ├── pre_destroy.ps1             ← Lấy VPC_ID → clean ENIs trước khi destroy
    └── clean_enis.ps1              ← SSH vào EC2, minikube delete, terminate orphaned
```

---

## Yêu cầu

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) đã configure (`aws configure`)
- PowerShell / pwsh (cho scripts ENI cleanup trên Windows)
- AWS account với quyền: EC2, VPC, ALB, S3, DynamoDB, IAM

---

## Cách chạy

### Bước 1 — Bootstrap remote state (chỉ chạy lần đầu)

```bash
make create-s3-ddb
```

Tạo S3 bucket `dev-terraform-state-bucket-kduy` và DynamoDB table `dev-terraform-state-lock`.

### Bước 2 — Init Terraform

```bash
make init
```

### Bước 3 — Preview infrastructure

```bash
make plan
```

### Bước 4 — Deploy

```bash
make apply
```

Quá trình này mất khoảng **3-5 phút**, bao gồm:
- Provision VPC, subnets, IGW, SG, EC2, ALB, S3
- SSH vào EC2 cài Docker + kubectl + Minikube
- Start Minikube cluster
- Build Docker image `kube-container` từ `app/`
- Deploy K8s Deployment + Service
- Tạo systemd service cho `kubectl port-forward`

### Bước 5 — Lấy URL

```bash
make show
# Hoặc
terraform -chdir=environments/dev output alb_dns_link
```

Output: `http://<alb-dns>.us-east-1.elb.amazonaws.com`

### Bước 6 — Destroy

```bash
make destroy
```

Script `pre_destroy.ps1` tự động clean orphaned ENIs trước khi destroy.

---

## Biến cấu hình

| Variable | Default | Mô tả |
|---|---|---|
| `region` | `us-east-1` | AWS region |
| `vpc_name` | `dev-vpc` | Tên VPC và prefix cho resources |
| `owner` | `kduy` | Tag owner |
| `cidr_block` | `10.0.0.0/16` | CIDR của VPC |
| `instance_type` | `t3.small` | EC2 instance type |
| `bucket_name` | `dev-static-assets-kduy` | Tên S3 bucket |

---

## Kiến trúc request flow

```
Internet
   └── ALB :80
         └── EC2 t3.small (Ubuntu 20.04)
               └── kubectl port-forward :30080 → K8s Service :80
                     └── 4x Pod (Node.js :80)
```

---

## Troubleshooting

### State lock bị kẹt

```bash
make unlock-state LOCK_ID=<id-từ-error-message>
# Nếu thất bại:
make unlock-dynamo
```

### Destroy bị stuck (IGW/Subnet không xóa được)

```bash
make clean-enis VPC_ID=<vpc-id>
# Sau đó:
make destroy
```

Nguyên nhân: Minikube tạo Docker bridge network, để lại ENI orphaned khi EC2 bị terminate đột ngột.

---

## Lưu ý bảo mật

- SSH port 22 mở cho `0.0.0.0/0` — chỉ phù hợp cho lab/dev
- Private key SSH được generate bởi Terraform và lưu trong state → không commit state file
- File `*.pem`, `*.tfstate`, `*.tfvars` đã được thêm vào `.gitignore`
