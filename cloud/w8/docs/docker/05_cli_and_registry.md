# 05 — Docker CLI, Flags & Registry

> Các lệnh thường dùng nhất và cơ chế pull/push/tag với Docker Hub.

---

## Nhóm lệnh theo chức năng

### Build

```bash
# Build image từ Dockerfile trong thư mục hiện tại
docker build .

# Build với tag tên:version
docker build -t myapp:1.0 .

# Build với tag, chỉ định Dockerfile khác
docker build -t myapp:1.0 -f Dockerfile.prod .

# Build với build argument
docker build --build-arg ENV=production -t myapp:prod .

# Build không dùng cache (force rebuild toàn bộ)
docker build --no-cache -t myapp:1.0 .

# Xem chi tiết từng bước build
docker build --progress=plain -t myapp:1.0 .
```

---

### Run — Chạy container

```bash
# Cơ bản nhất
docker run nginx

# Flags quan trọng:
docker run \
  -d \                          # detach: chạy nền, không block terminal
  --name web \                  # đặt tên container (thay vì random)
  -p 8080:80 \                  # port mapping: host:container
  -e APP_ENV=production \       # set environment variable
  -v /host/path:/container/path \ # bind mount volume
  --rm \                        # tự xóa container khi stop
  --restart=always \            # tự restart nếu crash
  --memory="512m" \             # giới hạn RAM
  --cpus="1.0" \                # giới hạn CPU
  --network mynetwork \         # gắn vào network cụ thể
  nginx:1.25
```

**Giải thích `-p host:container`:**
```
-p 8080:80   → request vào localhost:8080 được forward vào port 80 trong container
-p 80:80     → host port 80 = container port 80
-p 0.0.0.0:8080:80  → bind tất cả interfaces (mặc định)
-p 127.0.0.1:8080:80 → chỉ bind localhost, không expose ra ngoài
```

**Chạy interactive:**
```bash
# Chạy shell trong container mới (xóa khi exit)
docker run -it --rm ubuntu bash

# -i: giữ stdin mở  -t: allocate pseudo-TTY
# Kết hợp -it để có interactive terminal
```

---

### Quản lý container đang chạy

```bash
# Xem container đang chạy
docker ps

# Xem tất cả container (kể cả đã stop)
docker ps -a

# Xem tóm tắt resource usage (live)
docker stats

# Xem logs
docker logs web
docker logs web -f              # follow (stream real-time)
docker logs web --tail=100      # 100 dòng cuối
docker logs web --since=1h      # 1 giờ gần đây

# Exec lệnh trong container đang chạy
docker exec web ls /app
docker exec -it web bash        # Mở shell trong container đang chạy

# Dừng container (gửi SIGTERM, chờ 10s, rồi SIGKILL)
docker stop web
docker stop -t 30 web           # Chờ 30s trước khi SIGKILL

# Kill ngay lập tức (SIGKILL)
docker kill web

# Khởi động lại
docker restart web

# Xóa container (phải stop trước)
docker rm web
docker rm -f web                # Force remove (stop + rm)

# Xóa tất cả container đã stop
docker container prune
```

---

### Quản lý Image

```bash
# Xem images đang có
docker images
docker image ls

# Xóa image
docker rmi nginx:1.25
docker image rm nginx:1.25

# Xóa images không dùng (dangling)
docker image prune

# Xóa tất cả images không dùng
docker image prune -a

# Xem chi tiết image (layers, config, metadata)
docker inspect nginx:1.25
docker history nginx:1.25       # Xem từng layer và size

# Copy file giữa container và host
docker cp web:/app/logs/error.log ./error.log
docker cp ./config.json web:/app/config.json
```

---

### Dọn dẹp

```bash
# Xóa tất cả: stopped containers + unused networks + dangling images + build cache
docker system prune

# Xóa luôn cả images không dùng (cẩn thận)
docker system prune -a

# Xem disk usage
docker system df
```

---

## Tag — Đặt tên cho Image

Tag là nhãn gắn vào image theo format: `[registry/][username/]image_name[:tag]`

```bash
# Tag image mới khi build
docker build -t myapp:1.0 .
docker build -t myapp:latest .

# Tag image đã có
docker tag myapp:1.0 myapp:stable
docker tag myapp:1.0 username/myapp:1.0            # chuẩn bị push lên Docker Hub
docker tag myapp:1.0 123456789.dkr.ecr.us-east-1.amazonaws.com/myapp:1.0  # ECR

# Một image có thể có nhiều tags (đều trỏ về cùng image ID)
docker images myapp
# REPOSITORY   TAG      IMAGE ID       CREATED
# myapp        1.0      abc123def456   2 hours ago
# myapp        latest   abc123def456   2 hours ago   ← cùng IMAGE ID
# myapp        stable   abc123def456   2 hours ago
```

**Convention tags phổ biến:**
- `latest` — version mới nhất (mặc định khi không chỉ tag)
- `1.0`, `1.2.3` — version cụ thể (semantic versioning)
- `1.0-alpine` — variant nhẹ dùng Alpine Linux
- `1.0-slim` — variant đã bỏ package không cần
- `production`, `staging` — môi trường

> **Cẩn thận `latest`:** `latest` không đảm bảo là phiên bản mới nhất — chỉ là tag mặc định khi không chỉ định. Trong production, luôn pin version cụ thể (`nginx:1.25.3`) để build reproducible.

---

## Docker Hub & Registry

### Docker Hub — Registry public mặc định

```bash
# Login
docker login
docker login -u username -p password    # non-interactive (CI/CD)

# Pull image (tự động pull từ Docker Hub nếu không có local)
docker pull nginx                       # → nginx:latest
docker pull nginx:1.25                  # version cụ thể
docker pull nginx:1.25-alpine

# Push image lên Docker Hub
# Bước 1: tag với đúng format username/repo:tag
docker tag myapp:1.0 myusername/myapp:1.0

# Bước 2: push
docker push myusername/myapp:1.0

# Logout
docker logout
```

### Cơ chế Pull

Khi `docker pull nginx:1.25`:

```
1. Docker kiểm tra local image cache
   → Có rồi: skip (trừ khi dùng --pull=always)
   → Chưa có: tiếp tục

2. Kết nối Docker Hub: https://registry-1.docker.io
   → Authenticate (nếu private repo)
   → Tìm manifest của nginx:1.25

3. Download manifest (JSON mô tả image: layers, config, platform)

4. Kiểm tra từng layer có trong local cache chưa
   → Có: skip layer đó
   → Chưa: download layer (content-addressed bằng SHA256)

5. Giải nén và lưu vào /var/lib/docker/overlay2/

6. Tag image vào local registry
```

```bash
# Xem manifest của image (không download)
docker manifest inspect nginx:1.25

# Pull image cho platform cụ thể (cross-platform build)
docker pull --platform=linux/amd64 nginx:1.25
docker pull --platform=linux/arm64 nginx:1.25    # Apple M1/M2
```

### Các Registry khác

```bash
# AWS ECR
aws ecr get-login-password --region ap-southeast-1 | \
  docker login --username AWS --password-stdin \
  123456789.dkr.ecr.ap-southeast-1.amazonaws.com

docker pull 123456789.dkr.ecr.ap-southeast-1.amazonaws.com/myapp:1.0
docker push 123456789.dkr.ecr.ap-southeast-1.amazonaws.com/myapp:1.0

# GitHub Container Registry
docker login ghcr.io -u USERNAME --password-stdin <<< $GITHUB_TOKEN
docker pull ghcr.io/myorg/myapp:1.0

# Self-hosted (chạy registry cục bộ)
docker run -d -p 5000:5000 --name registry registry:2
docker tag myapp:1.0 localhost:5000/myapp:1.0
docker push localhost:5000/myapp:1.0
```

---

## Quick Reference

```bash
# Vòng đời cơ bản
docker build -t app:1.0 .          # Build
docker run -d -p 8080:80 app:1.0   # Run (nền)
docker ps                           # Xem đang chạy
docker logs app -f                  # Xem log
docker exec -it app bash            # Vào bên trong
docker stop app                     # Dừng
docker rm app                       # Xóa

# Registry
docker pull image:tag               # Tải về
docker push user/image:tag          # Đẩy lên
docker tag src:tag dst:tag          # Đổi tên/tag
```

---

**Tiếp theo:** [06_volumes.md](./06_volumes.md) — Giữ data khi container bị xóa với Volumes.
