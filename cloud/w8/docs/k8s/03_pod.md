# 03 — Pod

> Pod là đơn vị nhỏ nhất trong K8s — không phải Container.

---

## Pod là gì?

Pod là **lớp vỏ bọc** chứa một hoặc nhiều containers chạy cùng nhau trên cùng một Node. Các containers trong cùng một Pod:

- Chia sẻ **network namespace** — cùng IP, cùng port space
- Chia sẻ **storage** — có thể mount cùng volume
- Luôn được **schedule cùng nhau** — không bao giờ bị tách ra khác Node

```
┌─────────────────────────────────┐
│              Pod                │
│  IP: 10.0.0.5                   │
│                                 │
│  ┌─────────────┐ ┌───────────┐  │
│  │  Container  │ │ Sidecar   │  │
│  │  (main app) │ │ (log agent│  │
│  │  port: 8080 │ │ port: 9090│  │
│  └─────────────┘ └───────────┘  │
│                                 │
│  Volume: /data (shared)         │
└─────────────────────────────────┘
```

### Tại sao không phải Container mà là Pod?

Vì một số patterns cần nhiều containers **cộng tác chặt chẽ**:

**Sidecar pattern** — Container phụ hỗ trợ container chính. Ví dụ: log agent đọc log file từ volume và ship lên ELK, trong khi app chỉ cần write log ra file.

**Init containers** — Container chạy trước container chính để chuẩn bị môi trường (migrate database, chờ service khác sẵn sàng...).

Trong thực tế, **95% Pod chỉ có 1 container**. Multi-container Pod là pattern nâng cao.

---

## Tính Ephemeral — Quan trọng nhất cần nhớ

Pod được thiết kế để **"phù du"** — có thể bị xóa và tái tạo bất cứ lúc nào vì:

- Node bị chết hoặc hết tài nguyên
- Rolling update (xóa Pod cũ, tạo Pod mới)
- Health check thất bại quá nhiều lần
- Manual delete

Khi Pod bị xóa và tạo lại:
- **IP thay đổi** → đừng bao giờ hardcode IP của Pod
- **Filesystem bị reset** → dữ liệu ghi vào container bị mất
- **Tên giữ nguyên** nếu dùng qua Deployment (nhưng suffix thay đổi)

```
# Pod cũ bị xóa
web-pod-abc123   → DELETED

# Pod mới được tạo với IP khác
web-pod-xyz789   → RUNNING (IP: 10.0.0.8, khác với 10.0.0.5 lúc trước)
```

> **Hệ quả quan trọng:** Không bao giờ lưu state quan trọng trong container filesystem. Database, file uploads → phải dùng **Persistent Volume** hoặc dịch vụ ngoài (S3, RDS).

---

## Pod Lifecycle

```
Pending → Running → Succeeded/Failed
                 ↘ Unknown
```

**Pending** — Pod đã được tạo, Scheduler đang tìm Node phù hợp, hoặc đang pull image.

**Running** — Pod đã được gán Node, ít nhất 1 container đang chạy.

**Succeeded** — Tất cả containers exit với code 0 (dùng cho batch jobs).

**Failed** — Ít nhất 1 container exit với code khác 0.

**Unknown** — Không liên lạc được với Node (Node có thể đã chết).

---

## Viết Pod YAML

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-server
  labels:              # Labels dùng để Select Pod (quan trọng với Service)
    app: web
    version: "1.0"
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    ports:
    - containerPort: 80

    # Giới hạn tài nguyên — luôn nên khai báo
    resources:
      requests:          # Tối thiểu cần có để schedule
        memory: "64Mi"
        cpu: "250m"      # 250 millicores = 0.25 CPU
      limits:            # Tối đa được dùng
        memory: "128Mi"
        cpu: "500m"

    # Biến môi trường
    env:
    - name: APP_ENV
      value: "production"
```

### requests vs limits

`requests` — K8s dùng để **schedule**: Pod này cần ít nhất 64Mi RAM và 0.25 CPU, chỉ đặt trên Node còn đủ tài nguyên đó.

`limits` — K8s dùng để **throttle/kill**: nếu container dùng quá 128Mi RAM → bị OOMKilled. Nếu dùng quá CPU → bị throttle (không kill).

> Không khai báo limits → một container có thể eat hết RAM của Node, làm crash các Pod khác. **Luôn khai báo cả hai.**

---

## Deployment — Cách đúng để chạy Pod

Không bao giờ tạo Pod trực tiếp trong production. Dùng **Deployment** để K8s quản lý lifecycle:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-server
spec:
  replicas: 3                    # Muốn 3 Pods
  selector:
    matchLabels:
      app: web                   # Deployment quản lý Pods có label này
  template:                      # Template để tạo Pod
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
```

Deployment mang lại:
- **Self-healing** — Pod crash → tự tạo lại
- **Scaling** — `kubectl scale deployment web-server --replicas=5`
- **Rolling update** — deploy version mới không downtime
- **Rollback** — `kubectl rollout undo deployment web-server`

---

## Các lệnh kubectl với Pod

```bash
# Xem danh sách Pods
kubectl get pods
kubectl get pods -o wide          # Thêm cột Node, IP

# Chi tiết một Pod
kubectl describe pod web-server

# Xem logs
kubectl logs web-server
kubectl logs web-server -f        # Follow (stream)
kubectl logs web-server --previous # Log của lần chạy trước (khi Pod crash)

# Exec vào container (như SSH)
kubectl exec -it web-server -- /bin/bash

# Xóa Pod
kubectl delete pod web-server
```

---

## Kiểm tra hiểu biết

1. Tại sao Pod được gọi là "ephemeral"? Hệ quả với việc lưu data?
2. `requests` và `limits` khác nhau thế nào và tại sao cần cả hai?
3. Tại sao không nên tạo Pod trực tiếp mà phải dùng Deployment?

---

**Tiếp theo:** [04_config.md](./04_config.md) — Quản lý cấu hình với ConfigMap và Secret.
