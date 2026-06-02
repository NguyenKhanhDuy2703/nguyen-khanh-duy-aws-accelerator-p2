# 06 — Volumes & Data Persistence

> Container filesystem là tạm thời — Volume là cách giữ data sống sót qua restart và xóa container.

---

## Vấn đề: Container filesystem là ephemeral

```bash
# Tạo file trong container
docker run --name test nginx bash -c "echo 'important data' > /data/myfile.txt"

# Xóa container
docker rm test

# Chạy container mới — file đã mất
docker run --name test2 nginx bash -c "cat /data/myfile.txt"
# → cat: /data/myfile.txt: No such file or directory
```

Write layer của container bị xóa cùng container. Mọi thứ ghi vào đó — log, upload, database — đều mất.

---

## 3 loại Storage trong Docker

```
┌────────────────────────────────────────────────────────────┐
│                      Docker Host                           │
│                                                            │
│  /var/lib/docker/volumes/    ← Named Volume               │
│  /any/path/on/host           ← Bind Mount                  │
│  RAM (tmpfs)                 ← tmpfs Mount                 │
│                                                            │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    Container                        │   │
│  │  /data   ← Named Volume mount                      │   │
│  │  /config ← Bind Mount                              │   │
│  │  /tmp    ← tmpfs Mount                             │   │
│  │  /app    ← Container write layer (ephemeral)       │   │
│  └─────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────┘
```

---

## 1. Named Volume — Cách khuyến nghị

Docker quản lý hoàn toàn. Data nằm trong `/var/lib/docker/volumes/` trên host, nhưng bạn không cần quan tâm đến path đó.

```bash
# Tạo volume
docker volume create mydata

# Xem volumes
docker volume ls

# Chi tiết volume
docker volume inspect mydata
# {
#   "Name": "mydata",
#   "Mountpoint": "/var/lib/docker/volumes/mydata/_data",
#   "Driver": "local"
# }

# Dùng volume khi run container
docker run -d \
  --name postgres \
  -v mydata:/var/lib/postgresql/data \    # volume_name:container_path
  -e POSTGRES_PASSWORD=secret \
  postgres:15

# Xóa volume (chỉ xóa khi không có container dùng)
docker volume rm mydata

# Xóa volumes không dùng
docker volume prune
```

**Ưu điểm Named Volume:**
- Docker quản lý — không lo path trên host
- Dễ backup, migrate
- Hoạt động đúng trên mọi OS (Linux, Mac, Windows)
- Có thể share giữa nhiều containers

---

## 2. Bind Mount — Map thư mục từ host

Mount một thư mục cụ thể từ host vào container. Container thấy và sửa được file trực tiếp trên host.

```bash
# Syntax: -v /host/absolute/path:/container/path
docker run -d \
  --name web \
  -v $(pwd)/html:/usr/share/nginx/html \   # thư mục hiện tại/html
  -v $(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro \  # :ro = read-only
  -p 8080:80 \
  nginx

# Syntax mới (rõ ràng hơn):
docker run -d \
  --mount type=bind,source=$(pwd)/html,target=/usr/share/nginx/html \
  nginx
```

**Dùng khi nào:**
- Development: mount source code để hot reload không cần rebuild image
- Mount config file từ host (nginx.conf, ssl certs)
- Mount log directory để đọc log từ bên ngoài container

```bash
# Dev workflow điển hình: mount code, thay đổi ngay có effect
docker run -d \
  --name myapp-dev \
  -v $(pwd):/app \           # Mount toàn bộ source code
  -p 3000:3000 \
  myapp:dev npm run dev      # nodemon tự reload khi file thay đổi
```

**Cẩn thận:** Bind mount có nghĩa container có quyền đọc/ghi thư mục host. Nếu container bị compromise, attacker có thể modify file trên host.

---

## 3. tmpfs Mount — Lưu trong RAM

Data chỉ tồn tại trong RAM, không ghi xuống disk. Mất khi container stop hoặc restart.

```bash
docker run -d \
  --name myapp \
  --mount type=tmpfs,target=/tmp,tmpfs-size=100m \
  myapp

# Hoặc ngắn hơn (Linux only)
docker run -d --tmpfs /tmp:size=100m myapp
```

**Dùng khi nào:**
- Data nhạy cảm không muốn ghi disk (session token, encryption keys)
- Cache tạm thời cần tốc độ cao
- Scratch space cho processing

---

## So sánh 3 loại

| | Named Volume | Bind Mount | tmpfs |
|-|-------------|------------|-------|
| **Quản lý bởi** | Docker | OS/User | Docker (RAM) |
| **Vị trí** | `/var/lib/docker/volumes/` | Bất kỳ path nào | RAM |
| **Persistent** | ✓ qua restart | ✓ (file host) | ✗ mất khi stop |
| **Performance** | Tốt | Tốt (native FS) | Rất nhanh |
| **Share giữa containers** | ✓ | ✓ | ✗ |
| **Backup dễ** | ✓ | ✓ | ✗ |
| **Dev hot reload** | ✗ | ✓ | ✗ |
| **Dùng cho** | Database, app data | Dev, config, logs | Secrets, cache |

---

## Backup và Restore Volume

```bash
# Backup: chạy container tạm, tar data ra
docker run --rm \
  -v mydata:/source \             # Mount volume cần backup
  -v $(pwd):/backup \             # Mount thư mục lưu backup
  alpine tar czf /backup/mydata-backup.tar.gz -C /source .

# Restore:
docker volume create mydata-restored
docker run --rm \
  -v mydata-restored:/target \
  -v $(pwd):/backup \
  alpine tar xzf /backup/mydata-backup.tar.gz -C /target
```

---

## Volume trong Docker Compose

```yaml
# docker-compose.yml
version: "3.9"
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: secret
    volumes:
      - pgdata:/var/lib/postgresql/data    # Named volume

  nginx:
    image: nginx:1.25
    volumes:
      - ./html:/usr/share/nginx/html       # Bind mount
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    ports:
      - "8080:80"

volumes:
  pgdata:    # Khai báo named volume ở đây
```

```bash
docker compose up -d
docker compose down          # Stop containers, KHÔNG xóa volumes
docker compose down -v       # Stop containers VÀ xóa volumes (cẩn thận!)
```

---

## Patterns thường gặp

### Database — luôn dùng Named Volume

```bash
# PostgreSQL data phải persistent
docker run -d \
  --name postgres \
  -v pgdata:/var/lib/postgresql/data \
  -e POSTGRES_DB=myapp \
  -e POSTGRES_USER=user \
  -e POSTGRES_PASSWORD=secret \
  postgres:15
```

### Dev environment — Bind mount source code

```bash
docker run -d \
  --name myapp-dev \
  -v $(pwd):/app \           # Live code reload
  -v /app/node_modules \     # Anonymous volume cho node_modules — KHÔNG bind mount
  -p 3000:3000 \
  node:20 npm run dev
```

> `-v /app/node_modules` không có `:` nghĩa là anonymous volume. Trick này giữ `node_modules` của container, không bị ghi đè bởi `node_modules` của host (hoặc không có trên host).

### Log — Bind mount để đọc từ ngoài

```bash
docker run -d \
  --name nginx \
  -v /var/log/nginx:/var/log/nginx \  # Log ghi ra host, có thể ship với agent
  nginx
```

---

## Kiểm tra hiểu biết

1. Tại sao data mặc định trong container bị mất khi container bị xóa?
2. Khi nào dùng Named Volume, khi nào dùng Bind Mount?
3. `-v /app/node_modules` (không có `:`) khác gì `-v ./node_modules:/app/node_modules`?

---

**Hoàn thành Docker series!** Bước tiếp theo: **Docker Compose** (multi-container apps) và **Container networking** (bridge, host, overlay networks).
