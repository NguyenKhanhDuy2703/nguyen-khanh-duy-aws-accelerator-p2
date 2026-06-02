# 05 — Service

> Pod có IP động — Service cung cấp IP tĩnh và DNS ổn định để giao tiếp.

---

## Vấn đề Service giải quyết

Nhớ lại: Pod là ephemeral — khi crash và restart, **IP thay đổi**. Vậy làm sao service A gọi được service B nếu IP của B cứ thay đổi?

```
Frontend (10.0.0.3) → muốn gọi Backend
                    → Backend Pod crash → IP đổi thành 10.0.0.9
                    → Frontend không biết IP mới → lỗi connection
```

**Service** đứng ra làm trung gian — cung cấp một **địa chỉ IP ảo và DNS name ổn định** không bao giờ thay đổi, dù Pods bên dưới thay đổi IP liên tục.

---

## Service hoạt động như thế nào?

Service dùng **Label Selector** để tìm các Pods thuộc về nó:

```
Service (IP: 10.96.0.1, DNS: backend-svc)
   │
   │  selector: app=backend
   │
   ├── Pod backend-xyz (app=backend, IP: 10.0.0.5)
   ├── Pod backend-abc (app=backend, IP: 10.0.0.7)
   └── Pod backend-def (app=backend, IP: 10.0.0.9)
```

Traffic đến Service → kube-proxy load balance sang một trong các Pods phía sau (round-robin). Pod mới được tạo có đúng label → tự động được thêm vào pool. Pod crash và bị xóa → tự động bị remove khỏi pool.

---

## 3 loại Service chính

### 1. ClusterIP (mặc định)

Chỉ truy cập được **bên trong cluster**. Dùng cho giao tiếp giữa các services nội bộ.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
spec:
  type: ClusterIP       # Mặc định, có thể bỏ qua
  selector:
    app: backend        # Chọn Pods có label này
  ports:
  - port: 80            # Port của Service (client gọi vào đây)
    targetPort: 8080    # Port thật của container
```

```
Frontend Pod  →  backend-svc:80  →  Backend Pods :8080
              (DNS: backend-svc.default.svc.cluster.local)
```

DNS pattern trong K8s: `<service-name>.<namespace>.svc.cluster.local`. Trong cùng namespace, chỉ cần `backend-svc` là đủ.

---

### 2. NodePort

Mở một port trên **tất cả các Node** để truy cập từ bên ngoài cluster.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-svc
spec:
  type: NodePort
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080     # Port mở trên Node (range: 30000-32767)
                        # Bỏ qua → K8s tự chọn ngẫu nhiên
```

```
User  →  NodeIP:30080  →  web-svc:80  →  Web Pods :8080
```

**Hạn chế:** Phải biết IP của Node. Nếu Node thay đổi hoặc autoscaling, client phải biết IP mới. Thường chỉ dùng để **test/debug**, không dùng production.

---

### 3. LoadBalancer

Yêu cầu cloud provider (AWS, GCP, Azure) tạo một **External Load Balancer** với Public IP. Đây là cách expose service ra internet trong production trên cloud.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-svc
  annotations:
    # AWS-specific: dùng NLB thay vì CLB
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 8080
```

```
Internet  →  AWS ALB/NLB (Public IP)  →  web-svc  →  Web Pods
```

K8s tự động gọi AWS API để tạo Load Balancer và cấu hình target group. Khi Service bị xóa, Load Balancer cũng bị xóa theo.

**Hạn chế:** Mỗi Service LoadBalancer = một Load Balancer riêng → tốn tiền. Nếu có 10 services cần expose → 10 LB. Giải pháp tốt hơn: dùng **Ingress** (một LB cho nhiều services) — topic nâng cao.

---

## So sánh 3 loại Service

```
ClusterIP:    [Pod] → [Service] → [Pods]
              ↑ Chỉ trong cluster

NodePort:     [External] → [Node:30080] → [Service] → [Pods]
              ↑ Qua IP của Node

LoadBalancer: [Internet] → [Cloud LB] → [Service] → [Pods]
              ↑ Qua Public IP được cloud cấp
```

| | ClusterIP | NodePort | LoadBalancer |
|-|-----------|----------|--------------|
| **Truy cập** | Nội bộ cluster | Node IP:Port | Public IP |
| **Dùng khi** | Service-to-service | Dev/Debug | Production |
| **Chi phí** | Free | Free | Tốn phí cloud LB |

---

## Endpoint — Bên dưới Service

Service thực chất quản lý một object **Endpoints** chứa danh sách IP:Port của các Pods đang healthy:

```bash
kubectl get endpoints backend-svc
# NAME          ENDPOINTS                          AGE
# backend-svc   10.0.0.5:8080,10.0.0.7:8080       5m
```

Khi Pod bị xóa → IP tự động remove khỏi Endpoints. Khi Pod mới start → tự động thêm vào (sau khi Readiness Probe pass — xem file 06).

---

## Ví dụ thực tế: Frontend gọi Backend

```yaml
# Backend Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: api
        image: myapi:1.0
        ports:
        - containerPort: 8080
---
# Backend Service (ClusterIP — chỉ frontend trong cluster gọi)
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
spec:
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 8080
---
# Frontend gọi backend qua DNS: http://backend-svc/api/...
```

---

## Kiểm tra hiểu biết

1. Tại sao cần Service khi đã có IP của Pod?
2. Khi nào dùng ClusterIP, khi nào dùng LoadBalancer?
3. Service biết Pod nào còn sống và Pod nào đã chết bằng cơ chế gì?

---

**Tiếp theo:** [06_probes.md](./06_probes.md) — Liveness, Readiness, Startup Probe.
