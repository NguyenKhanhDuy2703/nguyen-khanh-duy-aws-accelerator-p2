# Exercise 8 — VPC + EC2 + ALB + Kubernetes Architecture Overview

> **Mục tiêu:** Deploy Node.js app trên Kubernetes (Minikube) chạy trên EC2, expose qua Application Load Balancer, provisioned hoàn toàn bằng Terraform với remote-exec automation.

---

## 1. Sơ đồ kiến trúc tổng quan

```mermaid
flowchart TB
        USER(["End User\nBrowser / curl"])

        subgraph AWS["AWS Cloud — us-east-1"]
            subgraph VPC["VPC: dev-vpc 10.0.0.0/16"]
                IGW["Internet Gateway"]

                subgraph SUBNETS["Public Subnets"]
                    AZ1["AZ 1a\n10.0.1.0/24"]
                    AZ2["AZ 1b\n10.0.2.0/24"]
                end

                subgraph SECURITY["Security Groups"]
                    SG_ALB["SG-ALB\nHTTP :80 open"]
                    SG_EC2["SG-EC2\nSSH :22 · :30080 from SG-ALB"]
                end

                ALB[["ALB: dev-vpc-alb\nHTTP :80 → Target :30080"]]

                subgraph EC2_BOX["EC2 — t3.small · Ubuntu 20.04"]
                    DOCKER["Docker 28.x"]
                    MINIKUBE["Minikube 1.35\nDriver: docker"]
                    PORTFWD["port-forward service\n0.0.0.0:30080 → svc:80"]

                    subgraph K8S["Kubernetes Cluster"]
                        SVC["Service: my-app-service\nNodePort :80→30080"]
                        DEPLOY["Deployment: my-app\nReplicas: 4 · kube-container"]
                        POD1["Pod 1\nnode:20-alpine"]
                        POD2["Pod 2\nnode:20-alpine"]
                        POD3["Pod 3\nnode:20-alpine"]
                        POD4["Pod 4\nnode:20-alpine"]
                    end
                end
            end

            S3[("S3: dev-static-assets-kduy\nVersioning + Encryption")]
        end

        subgraph TF["Terraform State Backend"]
            S3ST[("S3: terraform-state-bucket")]
            DDB[("DynamoDB: state-lock")]
        end

        USER -->|"1 · HTTP :80"| ALB
        IGW --> SUBNETS
        ALB --> IGW
        SG_ALB -. protects .-> ALB
        SG_EC2 -. protects .-> EC2_BOX
        ALB -->|"2 · forward :30080"| PORTFWD
        DOCKER --> MINIKUBE
        MINIKUBE --> K8S
        PORTFWD -->|"3 · port-forward"| SVC
        SVC -->|"4 · load balance"| POD1
        SVC --> POD2
        SVC --> POD3
        SVC --> POD4
        DEPLOY --> POD1
        DEPLOY --> POD2
        DEPLOY --> POD3
        DEPLOY --> POD4
```

---

## 1.1. Mô tả cách thức hoạt động

Sơ đồ này mô tả một kiến trúc public entry point qua ALB, nhưng toàn bộ ứng dụng lại chạy trên một EC2 instance đóng vai trò host cho Minikube. Người dùng chỉ nhìn thấy một endpoint duy nhất là ALB; phía sau đó, ALB chuyển request vào EC2 trên cổng `30080`, rồi EC2 chuyển tiếp request vào Kubernetes Service để phân phối đến các Pod của ứng dụng.

Luồng traffic đi theo thứ tự sau:

1. Người dùng gửi HTTP request đến ALB trên port `80`.
2. ALB chỉ nhận traffic từ Internet qua Security Group `SG-ALB`, sau đó forward sang EC2 ở port `30080`.
3. Trên EC2, một service `port-forward` giữ cổng `30080` luôn lắng nghe và chuyển request vào Kubernetes Service `my-app-service`.
4. Kubernetes Service phân phối request đến một trong 4 Pod của deployment `my-app` theo cơ chế load balancing mặc định.
5. Response đi ngược lại cùng đường: Pod → Service → port-forward → EC2 → ALB → người dùng.

Về bảo mật, kiến trúc này được siết ở nhiều lớp:

- `SG-ALB` chỉ mở port `80` cho Internet, không expose thẳng EC2.
- `SG-EC2` chỉ cho phép port `30080` từ chính `SG-ALB`, nên chỉ ALB mới có thể gọi vào EC2.
- Ứng dụng không được public trực tiếp từ Pod hay Service; mọi truy cập phải đi qua ALB và EC2 forwarding.
- EC2 nằm trong public subnet để nhận traffic từ ALB, nhưng backend ứng dụng vẫn bị che bởi lớp trung gian `port-forward` và Kubernetes Service.
- Terraform state được lưu riêng trong S3 và DynamoDB để tránh mất trạng thái và đảm bảo lock khi apply.
- S3 static assets được bật versioning và encryption để bảo vệ dữ liệu tĩnh.

Nếu triển khai production, bước tăng cường tiếp theo nên là bật HTTPS trên ALB bằng ACM, giới hạn SSH bằng IP whitelist hoặc SSM Session Manager, và cân nhắc thay `port-forward` bằng một cơ chế ingress/load balancer ổn định hơn.

## 2. Request Flow Chi Tiết (End-to-End)

```mermaid
sequenceDiagram
    participant User as 👤 User Browser
    participant DNS as 🌐 DNS
    participant ALB as ⚖️ Application LB
    participant TG as 🎯 Target Group
    participant EC2 as 🖥️ EC2 :30080
    participant PortFwd as 🔀 kubectl port-forward
    participant K8sSvc as 📡 K8s Service
    participant Pod as 🔷 Pod (Node.js)

    User->>DNS: http://dev-vpc-alb-xxx.us-east-1.elb.amazonaws.com
    DNS-->>User: ALB Public IP

    User->>ALB: HTTP GET / :80
    Note over ALB: SG-ALB: Allow :80 from 0.0.0.0/0

    ALB->>TG: Health check: GET / :30080
    TG-->>ALB: EC2 healthy ✅

    ALB->>EC2: Forward to target :30080
    Note over EC2: SG-EC2: Allow :30080 from SG-ALB

    EC2->>PortFwd: systemd service<br/>kubectl port-forward svc/my-app-service<br/>0.0.0.0:30080 → :80

    PortFwd->>K8sSvc: Route to Service :80
    Note over K8sSvc: Type: NodePort<br/>Selector: app=my-app

    K8sSvc->>Pod: Load balance to 1 of 4 pods
    Note over Pod: Image: kube-container<br/>EXPOSE 80

    Pod-->>K8sSvc: HTTP 200 + HTML response
    K8sSvc-->>PortFwd: Response
    PortFwd-->>EC2: Response
    EC2-->>ALB: Response
    ALB-->>User: HTTP 200 + Page content
```

---

## 3. Luồng Traffic Chi Tiết Theo Lớp

### **Layer 1: Internet → ALB (HTTP Entry Point)**

```mermaid
flowchart LR
    USER["👤 User"] -->|"HTTP :80"| SG_ALB["🛡️ SG-ALB<br/>Rule: Allow :80<br/>from 0.0.0.0/0"]
    SG_ALB -->|"✅ Allowed"| ALB["⚖️ ALB<br/>Listener: :80<br/>Protocol: HTTP"]
    ALB -->|"Route Rule:<br/>Default: forward to TG"| TG["🎯 Target Group<br/>Protocol: HTTP<br/>Port: 30080<br/>Health: GET / every 30s"]

    style USER fill:#e3f2fd,stroke:#1976d2
    style SG_ALB fill:#ffecb3,stroke:#f57c00
    style ALB fill:#b2dfdb,stroke:#00796b
    style TG fill:#c8e6c9,stroke:#388e3c
```

**Bảo mật Layer 1:**

- ✅ ALB public-facing → có Public IP
- ✅ SG-ALB chỉ mở port 80 (HTTP) → HTTPS nên dùng port 443 + ACM certificate
- ✅ ALB có WAF (Web Application Firewall) option (không enable trong lab)

---

### **Layer 2: ALB → EC2 (Target Group Health Check)**

```mermaid
sequenceDiagram
    participant ALB as ⚖️ ALB
    participant TG as 🎯 Target Group
    participant EC2 as 🖥️ EC2 :30080
    participant SG_EC2 as 🛡️ SG-EC2

    loop Every 30 seconds
        ALB->>TG: Check registered targets
        TG->>SG_EC2: Health check: GET / :30080<br/>Source: SG-ALB
        SG_EC2->>SG_EC2: Verify inbound rule<br/>✅ Port 30080 from SG-ALB
        SG_EC2->>EC2: Forward health check
        EC2-->>TG: HTTP 200 OK
        TG-->>ALB: Target healthy ✅
    end

    Note over TG: Unhealthy threshold: 2<br/>Healthy threshold: 2<br/>Timeout: 5s
```

**Bảo mật Layer 2:**

- ✅ SG-EC2 chỉ nhận port 30080 từ **SG-ALB** (SG-to-SG reference)
- ✅ Không mở 30080 cho `0.0.0.0/0` → chỉ ALB mới access được

---

### **Layer 3: EC2 → Kubernetes (kubectl port-forward)**

```mermaid
flowchart TB
    EC2_PORT["🔌 EC2 Port :30080<br/>(bound to 0.0.0.0)"]

    SYSTEMD["⚙️ systemd service<br/>kubectl-port-forward.service<br/>ExecStart: kubectl port-forward<br/>--address 0.0.0.0<br/>svc/my-app-service 30080:80"]

    KUBECTL["📡 kubectl CLI<br/>Connect to K8s API Server"]

    K8S_API["☸️ K8s API Server<br/>(Minikube internal)"]

    K8S_SVC["📡 Service: my-app-service<br/>Type: NodePort<br/>ClusterIP: 10.x.x.x<br/>Port: 80 → TargetPort: 80"]

    EC2_PORT --> SYSTEMD
    SYSTEMD --> KUBECTL
    KUBECTL --> K8S_API
    K8S_API --> K8S_SVC

    style EC2_PORT fill:#bbdefb,stroke:#1976d2
    style SYSTEMD fill:#c8e6c9,stroke:#388e3c
    style KUBECTL fill:#e1f5fe,stroke:#0288d1
    style K8S_API fill:#b3e5fc,stroke:#0288d1
    style K8S_SVC fill:#81d4fa,stroke:#0277bd
```

**Tại sao dùng kubectl port-forward thay vì NodePort trực tiếp?**

| Approach         | NodePort (K8s native)          | kubectl port-forward (Used in lab) |
| ---------------- | ------------------------------ | ---------------------------------- |
| **Port range**   | 30000-32767 (random)           | Any port (30080 custom)            |
| **Requires**     | Minikube tunnel / LoadBalancer | kubectl running as daemon          |
| **ALB Target**   | Không stable (port thay đổi)   | Cố định :30080                     |
| **Suitable for** | Multi-node cluster             | Single-node dev (Minikube)         |

**Bảo mật Layer 3:**

- ✅ `kubectl port-forward` chạy với user `ubuntu` (không phải root)
- ✅ systemd restart tự động nếu crash
- ⚠️ Nếu EC2 reboot → systemd auto-start

---

### **Layer 4: Kubernetes Service → Pods (Load Balancing)**

```mermaid
graph TB
    K8S_SVC["📡 Service: my-app-service<br/>selector: app=my-app<br/>Algorithm: Round-robin (default)"]

    POD1["🔷 Pod 1<br/>IP: 10.244.0.5<br/>app=my-app<br/>container port 80"]
    POD2["🔷 Pod 2<br/>IP: 10.244.0.6<br/>app=my-app<br/>container port 80"]
    POD3["🔷 Pod 3<br/>IP: 10.244.0.7<br/>app=my-app<br/>container port 80"]
    POD4["🔷 Pod 4<br/>IP: 10.244.0.8<br/>app=my-app<br/>container port 80"]

    K8S_SVC -->|"Request 1"| POD1
    K8S_SVC -->|"Request 2"| POD2
    K8S_SVC -->|"Request 3"| POD3
    K8S_SVC -->|"Request 4"| POD4
    K8S_SVC -->|"Request 5"| POD1

    style K8S_SVC fill:#b3e5fc,stroke:#0288d1,stroke-width:2px
    style POD1 fill:#4fc3f7,stroke:#0277bd
    style POD2 fill:#4fc3f7,stroke:#0277bd
    style POD3 fill:#4fc3f7,stroke:#0277bd
    style POD4 fill:#4fc3f7,stroke:#0277bd
```

**K8s Service Configuration:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app-service
spec:
  type: NodePort
  selector:
    app: my-app # Match pods with this label
  ports:
    - protocol: TCP
      port: 80 # Service port (ClusterIP)
      targetPort: 80 # Pod container port
      nodePort: 30080 # Exposed on EC2 (unused in this setup)
```

**Bảo mật Layer 4:**

- ✅ Pods isolated trong K8s network (10.244.0.0/16)
- ✅ Service chỉ route đến pods có label `app=my-app`
- ✅ Pods không có Public IP → chỉ accessible qua Service

---

## 4. Security Architecture Deep Dive

### **4.1. Security Groups Configuration**

```mermaid
graph TB
    subgraph INTERNET["🌐 Internet (0.0.0.0/0)"]
        ANY["Any IP Address"]
    end

    subgraph SG_ALB_RULES["🛡️ SG-ALB Rules"]
        ALB_IN["📥 Inbound:<br/>Protocol: TCP<br/>Port: 80<br/>Source: 0.0.0.0/0"]
        ALB_OUT["📤 Outbound:<br/>ALL (default)"]
    end

    subgraph SG_EC2_RULES["🛡️ SG-EC2 Rules"]
        EC2_IN_SSH["📥 Inbound 1:<br/>Protocol: TCP<br/>Port: 22<br/>Source: 0.0.0.0/0<br/>(⚠️ Should restrict)"]
        EC2_IN_APP["📥 Inbound 2:<br/>Protocol: TCP<br/>Port: 30080<br/>Source: SG-ALB"]
        EC2_OUT["📤 Outbound:<br/>ALL (default)"]
    end

    ANY -->|"HTTP :80"| ALB_IN
    ALB_IN --> ALB_OUT

    ANY -.->|"SSH :22<br/>(⚠️ Open)"| EC2_IN_SSH
    ALB_OUT -->|"Forward :30080"| EC2_IN_APP
    EC2_IN_APP --> EC2_OUT

    style INTERNET fill:#e3f2fd,stroke:#1976d2
    style SG_ALB_RULES fill:#fff3e0,stroke:#f57c00
    style SG_EC2_RULES fill:#ffecb3,stroke:#f57c00
    style EC2_IN_SSH fill:#ffcdd2,stroke:#d32f2f
    style EC2_IN_APP fill:#c8e6c9,stroke:#388e3c
```

**Security Group Matrix:**

| SG Name    | Direction | Protocol | Port  | Source/Destination | Purpose                            | Security Level        |
| ---------- | --------- | -------- | ----- | ------------------ | ---------------------------------- | --------------------- |
| **SG-ALB** | Inbound   | TCP      | 80    | 0.0.0.0/0          | Public HTTP access                 | ✅ Expected           |
| **SG-ALB** | Outbound  | ALL      | ALL   | 0.0.0.0/0          | Response + health checks           | ✅ Stateful           |
| **SG-EC2** | Inbound   | TCP      | 22    | 0.0.0.0/0          | SSH admin access                   | ⚠️ **HIGH RISK**      |
| **SG-EC2** | Inbound   | TCP      | 30080 | **SG-ALB**         | ALB → EC2 traffic                  | ✅ Secured (SG-to-SG) |
| **SG-EC2** | Outbound  | ALL      | ALL   | 0.0.0.0/0          | Internet access (apt, docker pull) | ✅ Required           |

---

### **4.2. Threat Model & Mitigation**

```mermaid
graph TB
    subgraph THREATS["⚠️ Potential Threats"]
        T1["1. SSH Brute Force<br/>(Port 22 open to world)"]
        T2["2. DDoS on ALB<br/>(Public HTTP endpoint)"]
        T3["3. Container Escape<br/>(Docker on EC2)"]
        T4["4. State File Exposure<br/>(Contains SSH keys)"]
    end

    subgraph MITIGATIONS["✅ Current Mitigations"]
        M1["🔒 AWS Shield Standard<br/>(Built-in DDoS protection)"]
        M2["🔐 SG-to-SG reference<br/>(EC2 not directly exposed)"]
        M3["💾 S3 encryption + versioning<br/>(State file protected)"]
        M4["🛡️ Docker rootless mode<br/>(Optional - not enabled)"]
    end

    subgraph RECOMMENDATIONS["💡 Production Recommendations"]
        R1["🔑 Restrict SSH to VPN CIDR<br/>OR use AWS Systems Manager"]
        R2["🌐 Enable ALB access logs<br/>(Audit trail in S3)"]
        R3["🔥 Add WAF rules<br/>(SQL injection, XSS protection)"]
        R4["📊 Enable VPC Flow Logs<br/>(Network traffic monitoring)"]
        R5["🔐 Use AWS Secrets Manager<br/>(No hardcoded credentials)"]
    end

    T1 -.-> M2
    T1 -.-> R1
    T2 -.-> M1
    T2 -.-> R3
    T3 -.-> M4
    T4 -.-> M3
    T4 -.-> R5

    style THREATS fill:#ffcdd2,stroke:#d32f2f
    style MITIGATIONS fill:#c8e6c9,stroke:#388e3c
    style RECOMMENDATIONS fill:#fff9c4,stroke:#f9a825
```

---

### **4.3. Terraform Provisioning Security**

```mermaid
sequenceDiagram
    participant Dev as 👨‍💻 Developer
    participant TF as ⚙️ Terraform
    participant AWS as ☁️ AWS API
    participant EC2 as 🖥️ EC2 Instance
    participant Remote as 🔧 remote-exec

    Dev->>TF: terraform apply
    TF->>AWS: Create EC2 + SSH Key Pair
    AWS-->>TF: EC2 IP + Private Key
    Note over TF: ⚠️ Private key stored in state

    TF->>EC2: Wait for SSH ready (30s)
    TF->>Remote: SSH connection (using private key)
    Remote->>EC2: Install Docker
    Remote->>EC2: Install kubectl + minikube
    Remote->>EC2: minikube start --driver=docker
    Remote->>EC2: docker build -t kube-container
    Remote->>EC2: kubectl apply -f deployment.yaml
    Remote->>EC2: Create systemd service (port-forward)
    EC2-->>TF: Provisioning complete

    Note over TF,AWS: ✅ Automated - No manual SSH needed<br/>⚠️ BUT state contains SSH key
```

**Security Concerns:**

- ⚠️ **remote-exec** requires SSH key → stored in Terraform state (S3)
- ⚠️ State file = sensitive data → MUST enable S3 encryption
- ✅ **Mitigation:** S3 bucket versioning + encryption + restricted IAM access

---

## 5. Terraform Modules & Dependency Graph

```mermaid
graph TB
    ROOT["📄 environments/dev/main.tf<br/><small>Root Module</small>"]

    VPC["📦 modules/vpc/<br/>- VPC: 10.0.0.0/16<br/>- 2 Public Subnets (AZ 1a, 1b)<br/>- Internet Gateway<br/>- Public Route Table"]

    SECURITY["📦 modules/security/<br/>- SG-ALB (port 80)<br/>- SG-EC2 (port 22, 30080 from SG-ALB)"]

    STORAGE["📦 modules/storage/<br/>- S3 bucket (static assets)<br/>- Versioning + Encryption"]

    COMPUTE["📦 modules/compute/<br/>├─ ec2.tf<br/>│   ├─ tls_private_key<br/>│   ├─ aws_key_pair<br/>│   ├─ aws_instance<br/>│   └─ remote-exec provisioner<br/>└─ alb.tf<br/>    ├─ aws_lb<br/>    ├─ aws_lb_target_group<br/>    ├─ aws_lb_listener<br/>    └─ aws_lb_target_group_attachment"]

    ROOT --> VPC
    ROOT --> SECURITY
    ROOT --> STORAGE
    ROOT --> COMPUTE

    SECURITY -.->|"vpc_id"| VPC
    COMPUTE -.->|"subnet_id<br/>security_group_ids<br/>vpc_id"| VPC
    COMPUTE -.->|"ec2_sg_id<br/>alb_sg_id"| SECURITY

    style ROOT fill:#ffeb3b,stroke:#f57c00,stroke-width:3px
    style VPC fill:#e8f5e9,stroke:#388e3c
    style SECURITY fill:#fff3e0,stroke:#f57c00
    style STORAGE fill:#fff9c4,stroke:#f9a825
    style COMPUTE fill:#bbdefb,stroke:#1976d2
```

**Deployment Order:**

1. **VPC Module** → Network foundation (VPC, subnets, IGW)
2. **Security Module** → Security Groups (depends on vpc_id)
3. **Storage Module** → S3 bucket (independent)
4. **Compute Module** → EC2 + ALB (depends on VPC + Security)

**Critical Dependencies:**

- ALB needs **2 subnets** in different AZs (HA requirement)
- EC2 needs **subnet_id** + **security_group_id**
- Target Group attachment needs **EC2 instance_id**

---

## 6. Lifecycle & Destroy Flow

### **6.1. Normal Destroy (Ideal Case)**

```mermaid
sequenceDiagram
    participant Dev as 👨‍💻 Developer
    participant Make as 📄 Makefile
    participant TF as ⚙️ Terraform
    participant AWS as ☁️ AWS API

    Dev->>Make: make destroy
    Make->>TF: terraform destroy -auto-approve

    TF->>AWS: 1. Detach Target Group attachment
    TF->>AWS: 2. Delete ALB Listener
    TF->>AWS: 3. Delete Target Group
    TF->>AWS: 4. Delete ALB
    TF->>AWS: 5. Terminate EC2
    TF->>AWS: 6. Delete SSH Key Pair
    TF->>AWS: 7. Delete Security Groups
    TF->>AWS: 8. Detach IGW
    TF->>AWS: 9. Delete Subnets
    TF->>AWS: 10. Delete Route Tables
    TF->>AWS: 11. Delete VPC
    TF->>AWS: 12. Delete S3 bucket

    AWS-->>TF: All resources deleted ✅
    TF-->>Dev: Destroy complete
```

---

### **6.2. Problematic Destroy (ENI Leak Issue)**

```mermaid
graph TB
    START["🚀 make destroy"] --> DETACH["1. Detach ALB targets"]
    DETACH --> DELETE_ALB["2. Delete ALB"]
    DELETE_ALB --> TERMINATE["3. Terminate EC2"]

    TERMINATE -->|"EC2 terminated"| ENI_CHECK{"4. Check ENIs<br/>still attached?"}

    ENI_CHECK -->|"No orphans"| DELETE_SG["5. Delete Security Groups"]
    DELETE_SG --> DELETE_SUBNET["6. Delete Subnets"]
    DELETE_SUBNET --> DELETE_VPC["7. Delete VPC ✅"]

    ENI_CHECK -->|"⚠️ Orphaned ENIs<br/>(Minikube Docker bridge)"| STUCK["❌ STUCK:<br/>- DependencyViolation<br/>- Subnets have ENIs<br/>- IGW still attached"]

    STUCK -.->|"Manual fix"| SCRIPT["🔧 clean_enis.ps1<br/>1. SSH minikube delete<br/>2. Terminate orphaned instances<br/>3. Wait terminated"]

    SCRIPT --> RETRY["♻️ Retry destroy"]
    RETRY --> DELETE_SG

    style START fill:#e3f2fd,stroke:#1976d2
    style STUCK fill:#ffcdd2,stroke:#d32f2f
    style SCRIPT fill:#fff9c4,stroke:#f9a825
    style DELETE_VPC fill:#c8e6c9,stroke:#388e3c
```

**Nguyên nhân ENI leak:**

- Minikube tạo Docker bridge network → attach ENI vào VPC
- Khi EC2 bị terminate đột ngột → ENI không được cleanup
- Terraform không track ENI này → không xóa tự động

**Giải pháp:** Pre-destroy script

---

### **6.3. Pre-Destroy Script Workflow**

```powershell
# scripts/pre_destroy.ps1
$VPC_ID = terraform -chdir=environments/dev output -raw vpc_id
pwsh -File scripts/clean_enis.ps1 -VpcId $VPC_ID
```

```powershell
# scripts/clean_enis.ps1
1. SSH vào EC2: `minikube delete` (graceful cleanup)
2. Query orphaned EC2 instances trong VPC
3. Terminate orphaned instances
4. Wait instance-terminated (polling)
5. Return success → Terraform destroy tiếp
```

---

## 7. Application Architecture (Node.js + Docker + K8s)

### **7.1. Container Build & Deploy Flow**

```mermaid
flowchart TD
    START["📁 app/ directory"] --> DOCKERFILE

    DOCKERFILE["📄 Dockerfile<br/>FROM node:20-alpine<br/>COPY index.js /app/<br/>EXPOSE 80<br/>CMD node /app/index.js"]

    DOCKER_BUILD["🐳 docker build<br/>-t kube-container .<br/>(on EC2 via remote-exec)"]

    IMAGE["📦 Docker Image<br/>kube-container:latest<br/>(local on EC2)"]

    K8S_YAML["📄 deployment.yaml<br/>- Deployment: 4 replicas<br/>- Service: NodePort<br/>- imagePullPolicy: Never"]

    KUBECTL_APPLY["⚙️ kubectl apply<br/>-f deployment.yaml"]

    K8S_DEPLOY["☸️ K8s Deployment<br/>Pull image from<br/>local Docker registry"]

    PODS["🔷 4x Pods<br/>Running kube-container"]

    DOCKERFILE --> DOCKER_BUILD
    DOCKER_BUILD --> IMAGE
    IMAGE --> K8S_YAML
    K8S_YAML --> KUBECTL_APPLY
    KUBECTL_APPLY --> K8S_DEPLOY
    K8S_DEPLOY --> PODS

    style START fill:#fff9c4,stroke:#f9a825
    style DOCKERFILE fill:#e1f5fe,stroke:#0288d1
    style IMAGE fill:#b3e5fc,stroke:#0288d1
    style PODS fill:#4fc3f7,stroke:#0277bd
```

**Key Point:** `imagePullPolicy: Never`

- Image được build local trên EC2
- K8s không pull từ Docker Hub / ECR
- Phù hợp cho dev/lab (production nên dùng registry)

---

### **7.2. Node.js Application Code**

```javascript
// app/index.js
const http = require("http");
const os = require("os");

const PORT = 80;
const HOSTNAME = os.hostname();

const server = http.createServer((req, res) => {
  res.statusCode = 200;
  res.setHeader("Content-Type", "text/html");
  res.end(`
    <h1>🚀 Hello from Kubernetes!</h1>
    <p>Pod: <strong>${HOSTNAME}</strong></p>
    <p>Request path: ${req.url}</p>
  `);
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`Server running at http://0.0.0.0:${PORT}/`);
});
```

**Features:**

- Hiển thị Pod hostname → verify load balancing works
- Listen `0.0.0.0` → accessible from K8s Service
- Port 80 → standard HTTP (không cần :8080)

---

## 8. High Availability Analysis

```mermaid
graph TB
    subgraph HA_COMPONENTS["✅ HA Components"]
        ALB_HA["⚖️ ALB<br/>- Cross-AZ: Yes<br/>- Subnets: 2 AZs<br/>- Auto-scaling: Built-in"]
        K8S_HA["☸️ K8s Pods<br/>- Replicas: 4<br/>- Auto-restart: Yes<br/>- Self-healing: Yes"]
    end

    subgraph SPOF["❌ Single Point of Failure"]
        EC2_SPOF["🖥️ EC2 Instance<br/>- Count: 1<br/>- AZ: Single (1a)<br/>- If fails: ALL pods down"]
        MINIKUBE_SPOF["☸️ Minikube<br/>- Type: Single-node<br/>- Not production-grade"]
    end

    subgraph RECOMMENDATIONS["💡 Production Upgrades"]
        ASG["🔄 Auto Scaling Group<br/>- Min: 2 EC2<br/>- Desired: 2<br/>- Max: 4"]
        EKS["☸️ Amazon EKS<br/>- Managed K8s<br/>- Multi-AZ control plane<br/>- Worker nodes in ASG"]
    end

    style HA_COMPONENTS fill:#c8e6c9,stroke:#388e3c
    style SPOF fill:#ffcdd2,stroke:#d32f2f
    style RECOMMENDATIONS fill:#fff9c4,stroke:#f9a825
```

**Current Setup:**

- ✅ ALB is HA (cross-AZ)
- ✅ Pods have replicas (4x)
- ❌ EC2 is single instance → SPOF
- ❌ Minikube is dev tool → not for production

**Production Path:**

1. Replace Minikube with **Amazon EKS** (managed K8s)
2. Deploy EC2 workers in **Auto Scaling Group** (2+ AZs)
3. Use **EKS Fargate** for serverless pods (optional)

---

## 9. Cost Analysis

```mermaid
pie title Estimated Monthly Cost (us-east-1)
    "EC2 t3.small (730h)" : 15.33
    "ALB + LCU" : 18.50
    "S3 Storage (10GB)" : 0.23
    "Data Transfer (50GB out)" : 4.50
    "DynamoDB (State Lock)" : 0.25
```

**Total:** ~$38.81/month

**Cost Breakdown:**
| Resource | Pricing | Monthly |
|---|---|---|
| EC2 t3.small | $0.021/hour | $15.33 |
| ALB (fixed) | $0.025/hour | $18.25 |
| ALB LCU | $0.008/LCU-hour | ~$0.25 (low traffic) |
| S3 Standard | $0.023/GB | $0.23 (10GB) |
| DynamoDB On-Demand | $1.25/million writes | $0.25 (state locks) |
| Data Transfer Out | $0.09/GB | $4.50 (50GB) |

**Cost Optimization Tips:**

- ✅ Use **t3.small** (burstable) thay vì t3.medium
- ⚠️ ALB cost cố định $18/tháng → đắt cho lab (cân nhắc dùng EC2 Public IP)
- ✅ Stop EC2 khi không dùng → chỉ trả S3 + DynamoDB
- ✅ S3 Lifecycle policy: xóa old versions sau 30 days

**For Lab/Dev:**

```bash
# Stop EC2 khi không dùng
aws ec2 stop-instances --instance-ids <id>

# Start lại khi cần
aws ec2 start-instances --instance-ids <id>
```

---

## 10. Monitoring & Observability

### **10.1. CloudWatch Metrics**

```mermaid
graph TB
    subgraph ALB_METRICS["⚖️ ALB Metrics"]
        ALB_REQ["RequestCount<br/>(requests/min)"]
        ALB_TARGET["HealthyHostCount<br/>UnhealthyHostCount"]
        ALB_LATENCY["TargetResponseTime<br/>(ms)"]
        ALB_ERROR["HTTPCode_Target_4XX_Count<br/>HTTPCode_Target_5XX_Count"]
    end

    subgraph EC2_METRICS["🖥️ EC2 Metrics"]
        EC2_CPU["CPUUtilization (%)"]
        EC2_NET["NetworkIn / NetworkOut"]
        EC2_DISK["DiskReadOps / DiskWriteOps"]
    end

    subgraph K8S_METRICS["☸️ Kubernetes (Manual)"]
        K8S_POD["kubectl top pods<br/>(CPU, Memory)"]
        K8S_NODE["kubectl top nodes"]
        K8S_EVENTS["kubectl get events<br/>--sort-by=.metadata.creationTimestamp"]
    end

    style ALB_METRICS fill:#b2dfdb,stroke:#00796b
    style EC2_METRICS fill:#bbdefb,stroke:#1976d2
    style K8S_METRICS fill:#e1f5fe,stroke:#0288d1
```

**Recommended Alarms:**

- ⚠️ ALB `UnhealthyHostCount > 0` → EC2 health check failing
- ⚠️ EC2 `CPUUtilization > 80%` → consider scaling
- ⚠️ ALB `HTTPCode_Target_5XX_Count > 10` → application errors

---

### **10.2. Logging Strategy**

```mermaid
flowchart LR
    ALB["⚖️ ALB Access Logs"] -->|"Store in"| S3_LOGS["📦 S3 Bucket<br/>alb-logs-*"]

    EC2["🖥️ EC2 System Logs"] -->|"CloudWatch Agent"| CW_LOGS["📊 CloudWatch Logs<br/>/aws/ec2/*"]

    K8S["☸️ kubectl logs"] -->|"Manual query<br/>OR FluentBit"| CW_K8S["📊 CloudWatch Logs<br/>/aws/containerinsights/*"]

    style S3_LOGS fill:#fff9c4,stroke:#f9a825
    style CW_LOGS fill:#e1f5fe,stroke:#0288d1
    style CW_K8S fill:#e1f5fe,stroke:#0288d1
```

**Enable ALB Access Logs:**

```terraform
resource "aws_lb" "main" {
  # ...

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    enabled = true
  }
}
```

---

## 11. Troubleshooting Guide

### **Issue 1: ALB returns 502 Bad Gateway**

**Symptoms:**

- Browser shows "502 Bad Gateway"
- ALB health check failing

**Debug Steps:**

```bash
# 1. Check Target Group health
aws elbv2 describe-target-health \
  --target-group-arn <arn>

# 2. SSH vào EC2, test port 30080
curl http://localhost:30080

# 3. Check kubectl port-forward running
systemctl status kubectl-port-forward

# 4. Check K8s pods
kubectl get pods
kubectl logs <pod-name>
```

**Common Fixes:**

- ✅ Restart port-forward: `systemctl restart kubectl-port-forward`
- ✅ Verify SG-EC2 allows :30080 from SG-ALB
- ✅ Check pods are Running: `kubectl get pods`

---

### **Issue 2: Terraform destroy stuck on VPC**

**Symptoms:**

```
Error: DependencyViolation: Network interface is currently in use
Error: DependencyViolation: The vpc 'vpc-xxx' has dependencies
```

**Solution:**

```bash
# Run pre-destroy script
make clean-enis VPC_ID=<vpc-id>

# Then retry
make destroy
```

---

### **Issue 3: EC2 không SSH được**

**Symptoms:** `Permission denied (publickey)` hoặc timeout

**Debug:**

```bash
# 1. Check SG-EC2 allows :22
aws ec2 describe-security-groups --group-ids <sg-id>

# 2. Verify EC2 có Public IP
aws ec2 describe-instances --instance-ids <id> \
  --query 'Reservations[0].Instances[0].PublicIpAddress'

# 3. Test SSH với verbose
ssh -vvv -i ec2_key.pem ubuntu@<public-ip>
```

---

## 12. Security Hardening Checklist

### **Before Production Deployment:**

#### **Network Security:**

- [ ] **SSH Access:** Restrict SG-EC2 port 22 to VPN CIDR or remove entirely (use AWS Systems Manager Session Manager)
- [ ] **HTTPS:** Replace ALB HTTP :80 listener with HTTPS :443 + ACM certificate
- [ ] **WAF:** Attach AWS WAF to ALB with rules for SQL injection, XSS, rate limiting
- [ ] **VPC Flow Logs:** Enable to capture all network traffic for audit
- [ ] **NAT Gateway:** Add if private resources need Internet (updates, Docker pulls)

#### **Compute Security:**

- [ ] **IAM Role:** Attach IAM role to EC2 instead of using AWS access keys
- [ ] **AMI Hardening:** Use CIS-hardened AMI or apply security benchmarks
- [ ] **Patch Management:** Enable AWS Systems Manager Patch Manager
- [ ] **Immutable Infrastructure:** Use Auto Scaling Group + Launch Template, không SSH vào EC2
- [ ] **Secrets Management:** Use AWS Secrets Manager cho DB passwords, API keys

#### **Container Security:**

- [ ] **Image Scanning:** Scan Docker images với Amazon ECR image scanning
- [ ] **Least Privilege:** Container chạy với non-root user
- [ ] **Network Policies:** Implement K8s Network Policies để isolate pods
- [ ] **Pod Security Standards:** Apply `restricted` PSS profile
- [ ] **Registry:** Push images lên private ECR, không dùng `imagePullPolicy: Never`

#### **Data Security:**

- [ ] **Encryption at Rest:** Enable EBS encryption cho EC2 volumes
- [ ] **Encryption in Transit:** TLS/HTTPS end-to-end
- [ ] **S3 Bucket Policies:** Restrict access to VPC Endpoints only
- [ ] **State File:** Rotate Terraform state encryption keys

#### **Monitoring & Incident Response:**

- [ ] **CloudWatch Alarms:** CPU, Memory, Disk, ALB 5xx errors
- [ ] **SNS Notifications:** Alert team when alarms trigger
- [ ] **AWS GuardDuty:** Enable threat detection
- [ ] **AWS Config:** Track compliance with security baselines
- [ ] **Backup Strategy:** Automated AMI snapshots, RDS backups (nếu có DB)

---

## 13. Comparison: Lab 1 vs Exercise 8

| Aspect            | Lab 1 (VPC+EC2+S3+RDS)                   | Exercise 8 (VPC+EC2+ALB+K8s)             |
| ----------------- | ---------------------------------------- | ---------------------------------------- |
| **Focus**         | 3-tier architecture<br/>(Web → App → DB) | Containerized app<br/>(ALB → K8s → Pods) |
| **Load Balancer** | ❌ None (EC2 direct access)              | ✅ ALB (HTTP load balancing)             |
| **Database**      | ✅ RDS MySQL (private subnet)            | ❌ None                                  |
| **Orchestration** | ❌ None                                  | ✅ Kubernetes (Minikube)                 |
| **Container**     | ❌ None                                  | ✅ Docker + K8s Pods (4 replicas)        |
| **Provisioning**  | Manual EC2 setup                         | ✅ Automated (remote-exec)               |
| **Availability**  | Single EC2 + RDS Multi-AZ                | Single EC2 + ALB Multi-AZ                |
| **Security**      | SG-to-SG (EC2 → RDS)                     | SG-to-SG (ALB → EC2)                     |
| **Cost**          | ~$31/month                               | ~$39/month (ALB adds $18)                |
| **Use Case**      | Traditional app + database               | Modern microservices                     |

**Learning Progression:**

1. **Lab 1:** Foundation networking + database integration
2. **Exercise 8:** Containerization + orchestration + load balancing
3. **Next Step:** Multi-AZ EKS cluster + RDS + CI/CD pipeline

---

## 14. Architecture Evolution Path

```mermaid
graph LR
    LAB1["📗 Lab 1<br/>VPC + EC2 + RDS<br/><small>Traditional 3-tier</small>"]

    EX8["📘 Exercise 8<br/>ALB + K8s (Minikube)<br/><small>Single-node container</small>"]

    PROD1["📙 Production V1<br/>ALB + EKS + RDS<br/><small>Multi-AZ managed K8s</small>"]

    PROD2["📕 Production V2<br/>ALB + EKS Fargate + Aurora<br/><small>Serverless containers</small>"]

    LAB1 -->|"Add ALB + Containers"| EX8
    EX8 -->|"Replace Minikube with EKS<br/>Add RDS + ASG"| PROD1
    PROD1 -->|"Fargate for pods<br/>Aurora Serverless"| PROD2

    style LAB1 fill:#c8e6c9,stroke:#388e3c
    style EX8 fill:#bbdefb,stroke:#1976d2
    style PROD1 fill:#fff9c4,stroke:#f9a825
    style PROD2 fill:#f8bbd0,stroke:#c2185b
```

---

## Kết luận

Exercise 8 nâng cấp từ Lab 1 với:

- ✅ **Load Balancer (ALB)** thay vì EC2 direct access → better scalability
- ✅ **Kubernetes** orchestration → container management, self-healing
- ✅ **Automated provisioning** (remote-exec) → infrastructure as code hoàn chỉnh
- ✅ **Multi-replica pods** → availability trong single node

**Điểm mạnh:**

- ALB cross-AZ → HA cho load balancing
- K8s Service → load balance across pods
- Docker containerization → portable, reproducible
- Terraform modules → reusable, maintainable

**Limitations:**

- Single EC2 → SPOF (production cần ASG)
- Minikube → dev tool (production cần EKS)
- SSH open to world → security risk

**Next Steps:**

- Implement CI/CD pipeline (GitHub Actions → ECR → EKS)
- Add monitoring (Prometheus + Grafana)
- Harden security (WAF, VPN, Secrets Manager)
- Migrate to EKS + Fargate

---

_Previous: [Lab 1 - Architecture Overview](../../cloud/w8/lab1-VPC+EC2+S3+RDS/ARCHITECTURE_OVERVIEW.md)_
