# 06 — Probes (Kiểm tra sức khỏe)

> K8s cần biết container có thực sự "khỏe" không — không chỉ đơn giản là "đang chạy".

---

## Vấn đề Probes giải quyết

Container đang chạy ≠ Container đang hoạt động tốt. Ví dụ:

- App bị **deadlock** — process còn đó nhưng không xử lý được request nào
- App đang **khởi động** — chưa load xong database connections, chưa sẵn sàng nhận traffic
- App **chậm startup** — cần 60 giây để warm up cache trước khi phục vụ được

Nếu K8s không biết những trường hợp này, nó sẽ:
- Không restart container bị deadlock (vì process vẫn running)
- Đẩy traffic vào container đang khởi động → request lỗi
- Kill container đang warm up vì "khởi động quá lâu"

**Ba loại Probe** giải quyết ba vấn đề khác nhau:

---

## 1. Liveness Probe — "Còn sống không?"

Kiểm tra container có cần **restart** không. Nếu thất bại liên tiếp → K8s kill và restart container.

**Dùng khi:** Detect deadlock, memory leak khiến app không respond được, trạng thái corrupt không tự recover được.

```yaml
spec:
  containers:
  - name: app
    image: myapp:1.0
    livenessProbe:
      httpGet:
        path: /health        # K8s gọi GET /health
        port: 8080
      initialDelaySeconds: 15  # Chờ 15s sau khi container start mới bắt đầu check
      periodSeconds: 20        # Check mỗi 20 giây
      failureThreshold: 3      # Thất bại 3 lần liên tiếp → restart
      timeoutSeconds: 5        # Timeout mỗi lần check
```

**Ví dụ endpoint `/health` trong app:**

```python
@app.route('/health')
def health():
    # Kiểm tra những thứ thực sự cần thiết để app hoạt động
    try:
        db.execute("SELECT 1")   # DB còn kết nối được không?
        return {"status": "ok"}, 200
    except Exception:
        return {"status": "error"}, 500  # → K8s sẽ restart
```

> **Cẩn thận:** Liveness Probe không nên check dependency bên ngoài (downstream services). Nếu service B chết, không nên vì vậy mà restart service A — A vẫn hoạt động tốt, chỉ là B có vấn đề.

---

## 2. Readiness Probe — "Sẵn sàng nhận traffic chưa?"

Kiểm tra container có sẵn sàng **phục vụ request** không. Nếu thất bại → K8s **tạm thời bỏ Pod ra khỏi Service Endpoints** (không restart).

**Dùng khi:** App cần thời gian warm up (load cache, build connection pool), hoặc tạm thời quá tải và cần "nghỉ" không nhận thêm traffic.

```yaml
spec:
  containers:
  - name: app
    image: myapp:1.0
    readinessProbe:
      httpGet:
        path: /ready
        port: 8080
      initialDelaySeconds: 5   # Chờ 5s mới check (ngắn hơn liveness)
      periodSeconds: 10
      failureThreshold: 3      # Thất bại 3 lần → remove khỏi Service
      successThreshold: 1      # Pass 1 lần → add lại vào Service
```

**Endpoint `/ready` kiểm tra kỹ hơn `/health`:**

```python
@app.route('/ready')
def ready():
    checks = {
        "cache_loaded": cache.is_ready(),      # Cache đã load chưa?
        "db_pool": db_pool.available > 0,      # DB pool còn slot không?
        "downstream": downstream.is_healthy()  # Dependencies sẵn sàng chưa?
    }
    if all(checks.values()):
        return {"status": "ready", "checks": checks}, 200
    return {"status": "not ready", "checks": checks}, 503
```

---

## 3. Startup Probe — "Đã khởi động xong chưa?"

Dành riêng cho app **khởi động chậm**. Trong khi Startup Probe chưa pass, Liveness và Readiness Probe bị **tạm dừng** — tránh K8s restart app đang warm up.

**Dùng khi:** App cần nhiều hơn 30-60 giây để start (Java apps, app cần load model ML lớn...).

```yaml
spec:
  containers:
  - name: slow-app
    image: java-app:1.0
    startupProbe:
      httpGet:
        path: /health
        port: 8080
      failureThreshold: 30     # Cho phép thất bại tối đa 30 lần
      periodSeconds: 10        # Check mỗi 10s
      # → Tổng thời gian chờ: 30 × 10 = 300 giây (5 phút)
      # Sau 5 phút mà vẫn chưa start → mới kill

    livenessProbe:             # Chỉ bắt đầu chạy sau khi startupProbe pass
      httpGet:
        path: /health
        port: 8080
      periodSeconds: 20
```

---

## Cơ chế kiểm tra — 3 loại

### HTTP GET (phổ biến nhất)

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
    httpHeaders:              # Optional: thêm header nếu cần
    - name: Authorization
      value: "Bearer token"
```

HTTP status 200-399 → success. 400+ → failure.

### TCP Socket

```yaml
livenessProbe:
  tcpSocket:
    port: 5432              # Chỉ check xem port có mở không
```

Dùng cho các protocol không phải HTTP (database, message queue). Chỉ check kết nối TCP được không, không kiểm tra nội dung.

### Exec Command

```yaml
livenessProbe:
  exec:
    command:
    - cat
    - /tmp/healthy           # File này tồn tại → app healthy
```

Exit code 0 → success. Khác 0 → failure. Dùng khi app không expose HTTP endpoint.

---

## Tất cả trong một Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: app
        image: myapp:1.0
        ports:
        - containerPort: 8080

        startupProbe:
          httpGet:
            path: /health
            port: 8080
          failureThreshold: 12
          periodSeconds: 5        # Cho tối đa 60s để start

        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 0  # startupProbe đã xử lý delay
          periodSeconds: 20
          failureThreshold: 3

        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 0
          periodSeconds: 10
          failureThreshold: 3
          successThreshold: 1
```

---

## Sơ đồ flow ba Probe

```
Container start
      │
      ▼
[Startup Probe running]
      │ pass
      ▼
[Liveness + Readiness bắt đầu chạy song song]
      │
      ├── Readiness fail → Remove khỏi Service Endpoints (không restart)
      │   Readiness pass → Add lại vào Service Endpoints
      │
      └── Liveness fail 3 lần → RESTART container
```

---

## Kiểm tra hiểu biết

1. Liveness và Readiness Probe khác nhau về **hành động** khi thất bại?
2. Tại sao Liveness Probe không nên check downstream services?
3. Startup Probe giải quyết vấn đề gì mà chỉ dùng Liveness/Readiness không giải quyết được?

---

**Tiếp theo:** [07_netpol.md](./07_netpol.md) — NetworkPolicy, firewall cho Pod.
