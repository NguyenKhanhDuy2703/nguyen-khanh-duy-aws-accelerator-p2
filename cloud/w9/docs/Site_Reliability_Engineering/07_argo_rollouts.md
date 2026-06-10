# 07 — Argo Rollouts: Canary Deployment trên Kubernetes

> **Mục tiêu:** Hiểu Rollout CRD, cách cấu hình canary strategy, và workflow từ deploy đến promote.

---

## 🚀 Argo Rollouts là gì?

Argo Rollouts là **Kubernetes controller** mở rộng native `Deployment` với khả năng triển khai nâng cao.

```
Kubernetes bình thường:           Với Argo Rollouts:
─────────────────────────         ──────────────────────────────────
Deployment CRD                    Rollout CRD
│                                 │
├── Chỉ có: RollingUpdate         ├── Canary (từng bước)
└── Không có:                     ├── Blue/Green
    - Phân tích metrics           ├── Analysis (Prometheus query)
    - Auto-rollback               ├── Auto-rollback khi fail
    - Canary traffic split        └── Manual promote/abort
```

---

## 🏗️ Kiến trúc Argo Rollouts

```
┌─────────────────────────────────────────────────────────────┐
│                     KUBERNETES CLUSTER                      │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Argo Rollouts Controller               │   │
│  │  (chạy trong cluster, watch Rollout resources)      │   │
│  └──────────────────────┬──────────────────────────────┘   │
│                         │ manages                           │
│            ┌────────────┴─────────────┐                    │
│            ▼                          ▼                     │
│    ┌──────────────┐          ┌──────────────────┐          │
│    │  Stable RS   │          │   Canary RS       │          │
│    │  (v1 - 95%)  │          │   (v2 - 5%)       │          │
│    │  ┌─────────┐ │          │   ┌─────────────┐ │          │
│    │  │Pod│Pod│  │ │          │   │Pod          │ │          │
│    │  └─────────┘ │          │   └─────────────┘ │          │
│    └──────────────┘          └──────────────────┘          │
│            │                          │                     │
│            └──────────┬───────────────┘                     │
│                       ▼                                     │
│              ┌─────────────────┐                           │
│              │   Service /     │                           │
│              │   Ingress       │                           │
│              │ (traffic split) │                           │
│              └─────────────────┘                           │
│                       │                                     │
│                       ▼                                     │
│                    USERS                                    │
└─────────────────────────────────────────────────────────────┘
```

---

## 📄 Rollout CRD — Cấu hình cơ bản

```yaml
# rollout.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout                       # Thay thế Deployment
metadata:
  name: payment-service
  namespace: production
spec:
  replicas: 10                      # Tổng số pods
  selector:
    matchLabels:
      app: payment-service
  template:
    metadata:
      labels:
        app: payment-service
    spec:
      containers:
      - name: payment-service
        image: payment-service:v1   # Version hiện tại
        ports:
        - containerPort: 8080

  # ─── CANARY STRATEGY ───────────────────────────────────────
  strategy:
    canary:
      # Service để route traffic
      canaryService: payment-canary-svc   # 5% traffic → đây
      stableService: payment-stable-svc  # 95% traffic → đây
      
      # Ingress để split traffic (nginx example)
      trafficRouting:
        nginx:
          stableIngress: payment-ingress
      
      # Các bước canary
      steps:
      - setWeight: 5          # Bước 1: 5% traffic → v2
      - pause: {duration: 10m}  # Chờ 10 phút
      
      - setWeight: 20         # Bước 2: 20%
      - pause: {duration: 10m}
      
      - setWeight: 50         # Bước 3: 50%
      - pause: {}             # Dừng, chờ approve thủ công
      
      - setWeight: 100        # Bước 4: 100% → deploy xong
```

---

## 🔧 Traffic Routing Options

```
Argo Rollouts hỗ trợ nhiều cách split traffic:

┌─────────────────────────────────────────────────────────────┐
│  INGRESS-BASED (đơn giản nhất)                             │
│                                                             │
│  nginx-ingress, AWS ALB, Traefik                           │
│  → Dùng annotation để split traffic                        │
│  → Không cần service mesh                                  │
│                                                             │
│  SERVICE MESH (mạnh nhất)                                  │
│                                                             │
│  Istio, Linkerd, AWS App Mesh                              │
│  → VirtualService / DestinationRule                        │
│  → Header-based routing (route specific users)             │
│  → Fine-grained traffic control                            │
│                                                             │
│  GATEWAY API (mới nhất, Kubernetes native)                 │
│                                                             │
│  HTTPRoute resource                                         │
│  → Chuẩn Kubernetes mới                                    │
│  → Không phụ thuộc vendor                                  │
└─────────────────────────────────────────────────────────────┘
```

### Ví dụ với Nginx Ingress

```yaml
# Service cho stable (95% traffic)
apiVersion: v1
kind: Service
metadata:
  name: payment-stable-svc
spec:
  selector:
    app: payment-service
  ports:
  - port: 80
    targetPort: 8080

---
# Service cho canary (5% traffic)
apiVersion: v1
kind: Service
metadata:
  name: payment-canary-svc
spec:
  selector:
    app: payment-service
  ports:
  - port: 80
    targetPort: 8080

---
# Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: payment-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: payment.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: payment-stable-svc   # Argo sẽ tự thêm canary
            port:
              number: 80
```

---

## 🎮 Workflow: Deploy một version mới

### Bước 1: Update image

```bash
# Thay đổi image trong Rollout
kubectl argo rollouts set image payment-service \
  payment-service=payment-service:v2 \
  -n production

# Hoặc edit trực tiếp
kubectl edit rollout payment-service -n production
```

### Bước 2: Theo dõi quá trình

```bash
# Watch real-time trong terminal
kubectl argo rollouts get rollout payment-service \
  --watch -n production

# Output sẽ trông như thế này:
# Name:            payment-service
# Namespace:       production
# Status:          ॐ Paused
# Strategy:        Canary
# Step:            1/4
# Set Weight:      5
# Actual Weight:   5
#
# NAME                                    KIND        STATUS     AGE  INFO
# ⟳ payment-service                       Rollout     ॐ Paused   10m
# ├──# revision:2                                                     
# │  └──⧉ payment-service-v2-abc123       ReplicaSet  ✔ Healthy  2m   canary
# │     └──□ payment-service-v2-abc123-xyz Pod         ✔ Running  2m   
# └──# revision:1                                                     
#    └──⧉ payment-service-v1-def456       ReplicaSet  ✔ Healthy  1h   stable
#       ├──□ payment-service-v1-def456-aaa Pod         ✔ Running  1h   
#       └──□ payment-service-v1-def456-bbb Pod         ✔ Running  1h   
```

### Bước 3: Promote hoặc Abort

```bash
# Approve để tiếp tục deploy
kubectl argo rollouts promote payment-service -n production

# Rollback ngay lập tức
kubectl argo rollouts abort payment-service -n production

# Rollback về version trước
kubectl argo rollouts undo payment-service -n production
```

---

## 🖥️ Argo Rollouts Dashboard

```
Argo Rollouts có Dashboard UI trực quan:

┌──────────────────────────────────────────────────────────┐
│  Argo Rollouts Dashboard                                 │
│                                                          │
│  payment-service                          ⚙ Canary      │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Status: Paused at step 2/4                        │  │
│  │  Canary Weight: 20%                                │  │
│  │                                                    │  │
│  │  Stable:  [━━━━━━━━━━━━━━━━━━━━━━━━━━━━] 8 pods   │  │
│  │  Canary:  [━━━━━━━━] 2 pods                       │  │
│  │                                                    │  │
│  │  [  Promote  ]  [  Abort  ]  [  Rollback  ]       │  │
│  └────────────────────────────────────────────────────┘  │
│                                                          │
│  Analysis Runs:                                          │
│  ✅ success-rate  │  ✅ latency-check  │  ⏳ Running    │  │
│                                                          │
└──────────────────────────────────────────────────────────┘

# Chạy dashboard local:
kubectl argo rollouts dashboard
# Mở: http://localhost:3100
```

---

## 📦 Cài đặt Argo Rollouts

```bash
# Cài controller
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts \
  -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Cài kubectl plugin
brew install argoproj/tap/kubectl-argo-rollouts
# Hoặc
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x kubectl-argo-rollouts-linux-amd64
mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts

# Verify
kubectl argo rollouts version
```

---

## 🔗 Tài liệu tiếp theo

- **[08_analysis_template.md](08_analysis_template.md)** — Tích hợp Prometheus để tự động analyze
- **[09_abort_criteria.md](09_abort_criteria.md)** — Abort criteria và auto-rollback
- Nguồn gốc: [Argo Rollouts Docs — Concepts & Analysis](https://argoproj.github.io/argo-rollouts)
