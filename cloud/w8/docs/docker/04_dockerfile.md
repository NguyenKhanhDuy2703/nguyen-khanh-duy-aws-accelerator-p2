# 04 — Dockerfile & Build Cache

> Dockerfile là công thức tạo Image — mỗi instruction tạo ra một layer.

---

## Dockerfile là gì?

File text tên `Dockerfile` (không có đuôi) chứa các lệnh theo thứ tự. Docker đọc từ trên xuống, mỗi lệnh tạo một layer mới trên layer trước.

```bash
docker build -t myapp:1.0 .
#            └─ tag name   └─ context (thư mục hiện tại)
```

---

## Các Instruction quan trọng

### `FROM` — Layer nền, luôn là lệnh đầu tiên

```dockerfile
FROM ubuntu:22.04
FROM python:3.11-slim          # slim = bỏ các package không cần thiết (~50MB vs ~300MB)
FROM node:20-alpine            # alpine = distro siêu nhỏ (~5MB base)
FROM scratch                   # Hoàn toàn rỗng — dùng cho static binary (Go, Rust)
```

**Chọn base image:** Ưu tiên `alpine` hoặc `slim` để image nhỏ. Image nhỏ = pull nhanh, attack surface nhỏ, bảo mật hơn.

---

### `WORKDIR` — Đặt thư mục làm việc

```dockerfile
WORKDIR /app
```

Tương đương `mkdir -p /app && cd /app`. Mọi lệnh `RUN`, `COPY`, `CMD` sau đó đều chạy trong `/app`. Nên dùng thay vì `RUN cd /app` vì `cd` không persist giữa các layer.

---

### `COPY` — Copy file từ host vào image

```dockerfile
COPY requirements.txt .          # Copy file vào WORKDIR
COPY src/ ./src/                 # Copy thư mục
COPY . .                         # Copy toàn bộ context vào WORKDIR

# --chown: set ownership ngay khi copy (thay vì RUN chown sau)
COPY --chown=app:app . .
```

**`COPY` vs `ADD`:**
- `COPY` chỉ copy file/thư mục — dùng trong 99% trường hợp
- `ADD` có thêm khả năng giải nén `.tar` và fetch URL — nên tránh vì implicit behavior

---

### `RUN` — Chạy lệnh lúc build image

```dockerfile
RUN apt-get update && apt-get install -y curl \
    && rm -rf /var/lib/apt/lists/*    # Xóa cache apt để giảm size layer

RUN pip install --no-cache-dir -r requirements.txt

RUN npm ci --only=production
```

**Gộp nhiều lệnh vào một `RUN`** bằng `&&` để tránh tạo quá nhiều layer và đảm bảo cleanup nằm cùng layer với install.

---

### `ENV` — Đặt biến môi trường

```dockerfile
ENV APP_ENV=production
ENV PORT=8080
ENV DB_HOST=localhost DB_PORT=5432    # Nhiều biến trên một dòng

# Dùng trong các lệnh sau
RUN echo "Running in $APP_ENV"
```

Biến `ENV` tồn tại **cả lúc build và lúc runtime** (trong container). Khác với `ARG` chỉ tồn tại lúc build.

---

### `ARG` — Biến chỉ dùng lúc build

```dockerfile
ARG VERSION=1.0
ARG BUILD_DATE

RUN echo "Building version $VERSION on $BUILD_DATE"
```

```bash
docker build --build-arg VERSION=2.0 --build-arg BUILD_DATE=$(date) .
```

---

### `EXPOSE` — Khai báo port (chỉ là documentation)

```dockerfile
EXPOSE 8080
EXPOSE 8080/tcp
EXPOSE 8080/udp
```

`EXPOSE` không thực sự mở port — nó chỉ **document** rằng container sẽ lắng nghe port này. Port thực sự được mở bằng `-p` khi `docker run`.

---

### `CMD` vs `ENTRYPOINT` — Lệnh chạy khi container start

```dockerfile
# CMD — lệnh mặc định, có thể override khi docker run
CMD ["python", "app.py"]
CMD ["nginx", "-g", "daemon off;"]

# ENTRYPOINT — lệnh không thể override (chỉ thêm arguments)
ENTRYPOINT ["python"]
CMD ["app.py"]             # Argument mặc định cho ENTRYPOINT
```

```bash
# Với CMD:
docker run myapp                    # → python app.py
docker run myapp python other.py    # → python other.py (override CMD)

# Với ENTRYPOINT + CMD:
docker run myapp                    # → python app.py
docker run myapp other.py          # → python other.py (CMD bị override, ENTRYPOINT giữ nguyên)
docker run --entrypoint bash myapp  # override ENTRYPOINT
```

**Dùng exec form** `["cmd", "arg"]` thay vì shell form `cmd arg` — exec form không wrap qua shell, process nhận signal đúng cách (SIGTERM khi `docker stop`).

---

### `USER` — Chạy với user không phải root

```dockerfile
RUN addgroup --system app && adduser --system --group app
USER app          # Mọi lệnh sau chạy với user "app", không phải root
```

Chạy container với root là security risk — nếu attacker escape container, họ có root trên host. Luôn tạo user riêng và `USER` trước `CMD`.

---

## Ví dụ Dockerfile hoàn chỉnh (Python)

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Copy requirements trước — tận dụng build cache
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy code sau (thay đổi thường xuyên hơn)
COPY . .

ENV APP_ENV=production
ENV PORT=8080

EXPOSE 8080

# Tạo user riêng, không chạy root
RUN addgroup --system app && adduser --system --group app
USER app

CMD ["python", "main.py"]
```

---

## Build Cache — Hiểu để tận dụng

Docker cache mỗi layer. Khi build lại, nếu instruction và input **không thay đổi** → dùng cache, không build lại layer đó.

```
Layer 1: FROM python:3.11-slim      → CACHE HIT  (image không đổi)
Layer 2: WORKDIR /app               → CACHE HIT
Layer 3: COPY requirements.txt .    → CACHE HIT  (file không đổi)
Layer 4: RUN pip install ...        → CACHE HIT  (layer trước không đổi)
Layer 5: COPY . .                   → CACHE MISS (code thay đổi!)
Layer 6: ENV, EXPOSE, USER, CMD     → rebuild (vì layer 5 miss)
```

**Quy tắc cache invalidation:**
- Một layer bị miss → toàn bộ các layer phía sau đều phải rebuild
- `COPY` bị miss nếu bất kỳ file nào trong source thay đổi
- `RUN` bị miss nếu instruction thay đổi hoặc layer trước thay đổi

**Chiến lược tối ưu — thứ tự đặt instruction:**

```dockerfile
# ❌ BAD: copy code trước, pip install sau
# → Sửa 1 dòng code = rebuild pip install (vài phút)
COPY . .
RUN pip install -r requirements.txt

# ✅ GOOD: copy requirements trước, pip install, rồi mới copy code
# → Sửa code chỉ rebuild từ layer COPY . . trở đi (vài giây)
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
```

**Bỏ qua file không cần thiết** với `.dockerignore`:

```
# .dockerignore
.git/
.env
__pycache__/
*.pyc
node_modules/
*.log
.DS_Store
README.md
tests/
```

---

## Multi-stage Build — Image production nhỏ hơn

```dockerfile
# Stage 1: Build (có đủ tools để compile)
FROM golang:1.21 AS builder
WORKDIR /app
COPY . .
RUN go build -o myapp .

# Stage 2: Run (chỉ cần binary, không cần Go SDK)
FROM alpine:3.18
WORKDIR /app
COPY --from=builder /app/myapp .    # Chỉ copy binary từ stage 1
CMD ["./myapp"]
```

Kết quả: image production chỉ ~10MB thay vì ~800MB (Go SDK + dependencies).

---

**Tiếp theo:** [05_cli_and_registry.md](./05_cli_and_registry.md) — Docker CLI, flags, pull/push, Docker Hub.
