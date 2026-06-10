# 01 — GitOps Principles: 4 nguyên tắc cốt lõi

> Nguồn: [OpenGitOps](https://opengitops.dev) — chuẩn do CNCF định nghĩa

---

## GitOps là gì?

GitOps là **phương pháp vận hành hạ tầng** trong đó:

- Toàn bộ trạng thái hệ thống được **khai báo dưới dạng file** (YAML, HCL, JSON)
- Các file đó được lưu trong **Git** là nơi duy nhất đáng tin cậy
- Một **agent tự động** (ArgoCD, Flux) liên tục đảm bảo cluster khớp với Git

GitOps **không phải** là một tool cụ thể — nó là một tập nguyên tắc. ArgoCD và Flux là các implementation của các nguyên tắc đó.

---

## 4 nguyên tắc cốt lõi (OpenGitOps v1.0)

### Nguyên tắc 1: Declarative (Khai báo)

Mô tả **cái gì** bạn muốn, không phải **làm thế nào** để đạt được nó.

```yaml
# ✅ GitOps style — khai báo desired state
apiVersion: apps/v1
kind: Deployment
spec:
  replicas: 3          # "Tôi muốn 3 replicas"
  template:
    spec:
      containers:
      - image: myapp:v2.1.0

# ❌ Non-GitOps — imperative
kubectl scale deployment myapp --replicas=3
kubectl set image deployment/myapp myapp=myapp:v2.1.0
```

**Tại sao quan trọng:** Lệnh imperative không để lại dấu vết trong Git, không thể audit, không thể rollback bằng `git revert`.

---

### Nguyên tắc 2: Versioned and Immutable (Có phiên bản, bất biến)

Git history chính là **audit log** của toàn bộ hệ thống.

```bash
git log --oneline k8s/production/
# a3f1c2d Deploy myapp v2.1.0 (2024-01-15 14:32 - @alice)
# 8b2e1f0 Scale API to 5 replicas (2024-01-14 09:15 - @bob)
# 3d4c5a1 Add Redis cache layer (2024-01-13 16:00 - @charlie)
```

Mỗi commit = một deployment record, có thể:
- Xem ai thay đổi gì (`git blame`)
- Rollback chính xác về thời điểm nào (`git revert`)
- So sánh 2 thời điểm bất kỳ (`git diff`)

---

### Nguyên tắc 3: Pulled Automatically (Kéo tự động)

Agent (ArgoCD/Flux) **kéo** (pull) thay đổi từ Git, **không phải** CI/CD push lên cluster.

```mermaid
flowchart TB
    subgraph PUSH["❌ Push Model (Traditional CI/CD)"]
        direction LR
        CI_PUSH["CI/CD Pipeline<br/>(Jenkins, GitHub Actions)"]
        K8S_PUSH["Kubernetes Cluster"]
        CI_PUSH -->|"push deploy<br/>(needs cluster credentials)"| K8S_PUSH
    end

    subgraph PULL["✅ Pull Model (GitOps)"]
        direction TB
        GIT["Git Repository<br/>(source of truth)"]
        ARGOCD["ArgoCD / Flux<br/>(runs inside cluster)"]
        K8S_PULL["Kubernetes API"]
        
        ARGOCD -->|"1. poll every 3min"| GIT
        ARGOCD -->|"2. apply changes"| K8S_PULL
    end

    style PUSH fill:#ffe6e6,stroke:#ff0000
    style PULL fill:#e6ffe6,stroke:#00aa00
    style CI_PUSH fill:#ffcccc
    style K8S_PUSH fill:#ffcccc
    style GIT fill:#ccffcc
    style ARGOCD fill:#ccffcc
    style K8S_PULL fill:#ccffcc
```

**Lợi ích bảo mật:** CI pipeline chỉ cần quyền push lên Git/registry, không cần `kubectl` credentials. Nếu CI bị compromise, attacker không thể deploy thẳng vào cluster.

**Lợi ích bảo mật:** CI pipeline chỉ cần quyền push lên Git/registry, không cần `kubectl` credentials. Nếu CI bị compromise, attacker không thể deploy thẳng vào cluster.

---

### Nguyên tắc 4: Continuously Reconciled (Liên tục đồng bộ)

Agent không chỉ deploy một lần — nó **liên tục** kiểm tra và sửa drift.

```mermaid
flowchart TD
    START([ArgoCD Agent Running]) --> POLL
    POLL["🔍 Poll Git repo<br/>Lấy desired state"]
    QUERY["📊 Query Kubernetes API<br/>Lấy actual state"]
    COMPARE{"🔄 So sánh<br/>desired vs actual"}
    MATCH["✅ States khớp nhau"]
    DRIFT["⚠️ Phát hiện drift"]
    APPLY["🔧 Apply changes<br/>Sync cluster về Git state"]
    SLEEP["💤 Chờ 3 phút<br/>(configurable)"]
    
    POLL --> QUERY
    QUERY --> COMPARE
    COMPARE -->|"Khớp"| MATCH
    COMPARE -->|"Lệch"| DRIFT
    MATCH --> SLEEP
    DRIFT --> APPLY
    APPLY --> SLEEP
    SLEEP --> POLL

    style START fill:#e3f2fd,stroke:#1976d2
    style POLL fill:#fff3e0,stroke:#f57c00
    style QUERY fill:#fff3e0,stroke:#f57c00
    style COMPARE fill:#fce4ec,stroke:#c2185b
    style MATCH fill:#e8f5e9,stroke:#388e3c
    style DRIFT fill:#ffebee,stroke:#d32f2f
    style APPLY fill:#e1f5fe,stroke:#0288d1
    style SLEEP fill:#f3e5f5,stroke:#7b1fa2
```

**Self-healing trong thực tế:**

```bash
# Ai đó sửa tay trên cluster lúc 2 giờ sáng
kubectl scale deployment myapp --replicas=1   # panic!

# 3 phút sau, ArgoCD phát hiện drift
# ArgoCD tự scale lại về replicas: 3 như trong Git
# Không cần ai làm gì
```

---

## Configuration Drift — vấn đề mà GitOps giải quyết

```mermaid
sequenceDiagram
    participant Git as Git Repo<br/>(source of truth)
    participant Dev as Developer
    participant Cluster as Kubernetes Cluster
    participant ArgoCD as ArgoCD Agent

    Note over Git,Cluster: Tuần 1 — Healthy State ✅
    Git->>Cluster: replicas: 3
    Note over Git,Cluster: Git = Cluster = 3 pods

    Note over Git,Cluster: Tuần 2 — Drift begins ⚠️
    Dev->>Cluster: kubectl scale --replicas=5<br/>(manual change)
    Note over Git,Cluster: Git = 3 | Cluster = 5 (DRIFT!)
    
    rect rgb(255, 235, 238)
        Note over ArgoCD: Without GitOps:<br/>Drift persists indefinitely
    end

    rect rgb(232, 245, 233)
        Note over ArgoCD: With GitOps (self-heal ON):
        ArgoCD->>Git: Poll (detect desired = 3)
        ArgoCD->>Cluster: Query (detect actual = 5)
        ArgoCD->>Cluster: Apply: scale back to 3
        Note over Git,Cluster: Auto-healed in 3 minutes ✅
    end

    Note over Git,Cluster: Tuần 3 — Prevented disaster 🛡️
    Dev->>Cluster: kubectl apply old-config.yaml
    ArgoCD->>Cluster: Revert to Git state
    Note over Cluster: ArgoCD always wins!
```

Với GitOps (ArgoCD self-heal ON):
- Bước 2: ArgoCD phát hiện trong 3 phút, revert về 3
- Bước 3: Không thể xảy ra vì `kubectl apply` sẽ bị ArgoCD override

---

## GitOps không phải silver bullet

| Tình huống | GitOps có giúp không? |
|---|---|
| Stateless app deployment | ✅ Rất phù hợp |
| Kubernetes config management | ✅ Rất phù hợp |
| Database schema migration | ⚠️ Cần tool thêm (PreSync hooks) |
| Secret management | ⚠️ Cần Sealed Secrets / Vault |
| Stateful workload (databases) | ⚠️ Phức tạp hơn |
| Non-Kubernetes infra (EC2, RDS) | ❌ Dùng Terraform thay thế |

---

*File tiếp theo: [02-github-actions.md](./02-github-actions.md)*
