# Exercise 8 — Architecture & IaC Flow

---

## 1. Cấu trúc thư mục

```
exersice_8/
│
├── Makefile                          ← Entrypoint: init / plan / apply / destroy
│
├── app/                              ← Application code (build & deploy vào K8s)
│   ├── index.js                      ← Node.js HTTP server (port 80)
│   ├── Dockerfile                    ← Build image: node:20-alpine
│   └── deployment.yaml               ← K8s Deployment + NodePort Service :30080
│
├── environments/
│   └── dev/
│       ├── main.tf                   ← Wires tất cả modules lại
│       ├── variables.tf              ← region, vpc_name, instance_type, ...
│       ├── outputs.tf                ← alb_dns_link, vpc_id, sg_ec2_id
│       └── backend.tf                ← Remote state → S3 + DynamoDB lock
│
├── modules/
│   ├── vpc/                          ← VPC, Subnets, IGW, Route Tables
│   ├── security/                     ← SG-ALB (port 80), SG-EC2 (port 22, 30080)
│   ├── compute/
│   │   ├── ec2.tf                    ← EC2 + SSH key + remote-exec provisioner
│   │   └── alb.tf                    ← ALB + Target Group + Listener + Attachment
│   └── storage/                      ← S3 bucket (static assets)
│
├── s3-ddb/                           ← Bootstrap: tạo S3 + DynamoDB cho remote state
│   └── main.tf
│
└── scripts/
    ├── pre_destroy.ps1               ← Lấy VPC ID → gọi clean_enis.ps1
    └── clean_enis.ps1                ← SSH minikube delete → terminate orphaned EC2
```

---

## 2. Luồng IaC (Terraform Execution Flow)

```
┌─────────────────────────────────────────────────────────────┐
│                        Developer                            │
│                    (PowerShell / CMD)                       │
└──────────────────────────┬──────────────────────────────────┘
                           │  make init / plan / apply / destroy
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                        Makefile                             │
│  init  → terraform init  (environments/dev)                 │
│  plan  → terraform plan                                     │
│  apply → terraform apply -auto-approve                      │
│  destroy → pre_destroy.ps1 → terraform destroy              │
└──────────────────────────┬──────────────────────────────────┘
                           │
              ┌────────────┴────────────┐
              │  Remote State Backend   │
              │  S3: terraform.tfstate  │
              │  DynamoDB: state lock   │
              │  (bootstrap: s3-ddb/)   │
              └────────────┬────────────┘
                           │ terraform apply
                           ▼
┌─────────────────────────────────────────────────────────────┐
│               environments/dev/main.tf                      │
│                                                             │
│  module.vpc ──────────────────────────────────────────────► │
│  module.security ─────── depends on vpc ──────────────────► │
│  module.storage ──────────────────────────────────────────► │
│  module.compute ─────── depends on vpc + security ────────► │
└──────────────────────────┬──────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────────┐
        ▼                  ▼                       ▼
  ┌───────────┐    ┌──────────────┐        ┌────────────┐
  │  module   │    │   module     │        │  module    │
  │   vpc     │    │  security    │        │  storage   │
  │           │    │              │        │            │
  │ VPC       │    │ sg-alb       │        │ S3 bucket  │
  │ 2x Public │    │  port 80     │        │ (versioned)│
  │ 2x Private│    │ sg-ec2       │        └────────────┘
  │ IGW       │    │  port 22     │
  │ Route TBL │    │  port 30080  │
  └───────────┘    └──────────────┘
                           │
                           ▼
              ┌────────────────────────┐
              │      module.compute    │
              │                        │
              │  tls_private_key       │
              │  aws_key_pair          │
              │         │              │
              │         ▼              │
              │  aws_instance (EC2)    │
              │  ┌─────────────────┐   │
              │  │ remote-exec:    │   │
              │  │ 1. Install      │   │
              │  │    Docker       │   │
              │  │ 2. Install      │   │
              │  │    kubectl +    │   │
              │  │    minikube     │   │
              │  │ 3. minikube     │   │
              │  │    start        │   │
              │  │ 4. Build image  │   │
              │  │    kube-container│  │
              │  │ 5. kubectl apply│   │
              │  │    deployment   │   │
              │  │ 6. systemd      │   │
              │  │    port-forward │   │
              │  │    :30080→:80   │   │
              │  └─────────────────┘   │
              │         │              │
              │         ▼              │
              │  aws_lb (ALB)          │
              │  aws_lb_target_group   │
              │  aws_lb_listener :80   │
              │  aws_lb_tg_attachment  │
              └────────────────────────┘

```

---

## 3. Request Flow (Runtime)

```
  Browser / curl
       │
       │  HTTP :80
       ▼
┌─────────────────────────────┐
│   ALB (Application LB)      │
│   dev-vpc-alb               │
│   Listener: port 80         │
└──────────────┬──────────────┘
               │  forward → Target Group
               │  health check: GET / :30080
               ▼
┌─────────────────────────────┐
│   EC2 (t3.small)            │
│   Ubuntu 20.04              │
│   port 30080 (systemd       │
│   kubectl port-forward)     │
└──────────────┬──────────────┘
               │  kubectl port-forward
               │  0.0.0.0:30080 → svc:80
               ▼
┌─────────────────────────────┐
│   Minikube (Docker driver)  │
│   K8s Service (NodePort)    │
│   my-app-service :30080→:80 │
└──────────────┬──────────────┘
               │  kube-proxy → Pod
               ▼
┌─────────────────────────────┐
│   Pod x2 (replicas)         │
│   image: kube-container     │
│   Node.js :80               │
│   (built from app/)         │
└─────────────────────────────┘
```

---

## 4. Destroy Flow

```
make destroy
     │
     ├─► scripts/pre_destroy.ps1
     │        │
     │        ├─ terraform output -raw vpc_id
     │        └─► scripts/clean_enis.ps1 -VpcId <id>
     │                  │
     │                  ├─ SSH → EC2
     │                  │    minikube delete      ← release Docker bridge ENIs
     │                  │    docker network prune
     │                  │
     │                  ├─ aws ec2 terminate-instances (orphaned)
     │                  └─ aws ec2 wait instance-terminated
     │
     └─► terraform destroy -auto-approve
              │
              ├─ aws_lb_target_group_attachment
              ├─ aws_lb_listener
              ├─ aws_lb / aws_lb_target_group
              ├─ aws_instance (EC2)
              ├─ aws_key_pair / tls_private_key
              ├─ aws_security_group (sg-ec2, sg-alb)
              ├─ aws_subnet (public x2, private x2)
              ├─ aws_internet_gateway
              ├─ aws_route_table + associations
              ├─ aws_vpc
              └─ aws_s3_bucket + versioning
```

---

## 5. Module Dependency Graph

```
                    ┌──────────────┐
                    │  environments│
                    │    /dev      │
                    └──────┬───────┘
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
      ┌─────────┐   ┌──────────┐   ┌──────────┐
      │  module │   │  module  │   │  module  │
      │   vpc   │   │ security │   │ storage  │
      └────┬────┘   └────┬─────┘   └──────────┘
           │             │ vpc_id
           │             │ vpc_id
           └──────┬───────┘
                  ▼
           ┌──────────┐
           │  module  │
           │ compute  │
           │          │
           │ ec2.tf   │ ← subnet_id, ec2_sg_id
           │ alb.tf   │ ← subnet_ids, alb_sg_id, vpc_id
           └──────────┘
```
