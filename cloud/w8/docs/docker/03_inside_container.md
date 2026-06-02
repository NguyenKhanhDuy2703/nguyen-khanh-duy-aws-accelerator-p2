# 03 — Bên Trong Container

> Container không phải "magic" — chỉ là 3 tính năng của Linux kernel kết hợp lại.

---

## Tổng quan

```
┌──────────────────────────────────────────────────────┐
│                    Container                         │
│                                                      │
│  ┌─────────────────┐  ┌────────────────────────────┐ │
│  │   Namespaces    │  │         cgroups             │ │
│  │  (cô lập)       │  │  (giới hạn tài nguyên)     │ │
│  │                 │  │                            │ │
│  │ • PID namespace │  │ • CPU: max 0.5 core        │ │
│  │ • NET namespace │  │ • Memory: max 512MB        │ │
│  │ • MNT namespace │  │ • I/O: max 100MB/s         │ │
│  │ • UTS namespace │  │ • PIDs: max 100 processes  │ │
│  │ • IPC namespace │  │                            │ │
│  │ • USER namespace│  └────────────────────────────┘ │
│  └─────────────────┘                                 │
│                                                      │
│  ┌──────────────────────────────────────────────────┐ │
│  │           Union Filesystem (OverlayFS)           │ │
│  │  Write layer (container riêng)  ← ghi được      │ │
│  │  Image layer 3 (app code)       ← read-only     │ │
│  │  Image layer 2 (dependencies)   ← read-only     │ │
│  │  Image layer 1 (base OS)        ← read-only     │ │
│  └──────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────┘
         Tất cả chạy trên cùng 1 Linux kernel
```

---

## 1. Namespaces — Cô lập

Namespace là cơ chế Linux cho phép **giả lập** rằng mỗi container có tài nguyên riêng — dù thực chất đều dùng chung kernel.

### PID Namespace
Container có bộ đếm PID riêng, bắt đầu từ 1.

```bash
# Bên trong container: chỉ thấy process của mình
$ docker exec mycontainer ps aux
PID   USER   COMMAND
1     root   nginx: master process nginx
7     nginx  nginx: worker process

# Bên ngoài host: thấy PID thật (ví dụ 4823, 4830)
$ ps aux | grep nginx
4823  root   nginx: master process nginx
4830  nginx  nginx: worker process
```

Process PID 1 trong container là "init" của container đó — nếu nó chết, container dừng.

### NET Namespace
Mỗi container có network interface riêng, routing table riêng, IP riêng.

```
Host network:       eth0 (192.168.1.10)
Container 1 net:    eth0 (172.17.0.2) — virtual interface
Container 2 net:    eth0 (172.17.0.3) — virtual interface
```

Docker tạo một virtual bridge `docker0` và kết nối tất cả containers vào đó. Containers giao tiếp với nhau qua bridge này.

### MNT Namespace (Mount)
Container có filesystem tree riêng. Không thấy được `/home/user` hay `/etc` của host, chỉ thấy filesystem của image.

### UTS Namespace (Unix Time Sharing)
Mỗi container có hostname riêng.
```bash
$ docker run --name web nginx hostname
# Output: a3f9d821c0b7 (container ID)
# Host vẫn có hostname riêng của nó
```

### IPC Namespace
Cô lập inter-process communication (shared memory, semaphores). Processes trong container A không thể giao tiếp shared memory với container B.

### USER Namespace
Map user ID bên trong container sang user ID khác trên host. Container chạy với `root` (uid=0) bên trong, nhưng thực tế là một user không có quyền trên host (uid=1000).

---

## 2. cgroups — Giới hạn tài nguyên

**Control Groups** là cơ chế Linux để giới hạn và theo dõi tài nguyên mà một nhóm processes được dùng.

Không có cgroups → một container có thể eat hết CPU và RAM của host, làm crash toàn bộ hệ thống.

```bash
# Giới hạn khi chạy container
docker run \
  --memory="512m" \          # Tối đa 512MB RAM
  --memory-swap="1g" \       # Tối đa 1GB swap
  --cpus="1.5" \             # Tối đa 1.5 CPU cores
  --pids-limit 100 \         # Tối đa 100 processes (chống fork bomb)
  nginx

# Xem resource usage
docker stats mycontainer
# CONTAINER   CPU %   MEM USAGE / LIMIT   NET I/O     BLOCK I/O
# web         0.1%    45MB / 512MB        2kB / 0B    0B / 0B
```

### Điều gì xảy ra khi vượt giới hạn?

**RAM vượt limit** → process bị **OOMKilled** (Out Of Memory Kill). Container exit, Docker có thể restart nếu có restart policy.

**CPU vượt limit** → process bị **throttle** — kernel cho chạy ít hơn, không bị kill. App chậm lại nhưng không crash.

---

## 3. Union Filesystem — Lưu trữ

Docker dùng **OverlayFS** (overlay filesystem) để xếp các layer thành một filesystem thống nhất mà container "nhìn thấy".

```
Container nhìn thấy:  /app/main.py  ← thực ra nằm ở write layer (nếu đã sửa)
                                        hoặc image layer (nếu chưa sửa)
                      /usr/bin/python ← nằm ở image layer 2
                      /bin/bash       ← nằm ở image layer 1 (base OS)

Thực tế ổ đĩa:
  upperdir (write layer):  /var/lib/docker/overlay2/abc123/diff/
  lowerdir (image layers): /var/lib/docker/overlay2/def456/diff/
                           /var/lib/docker/overlay2/ghi789/diff/
  merged view:             /var/lib/docker/overlay2/abc123/merged/  ← container thấy cái này
```

### Copy-on-Write (CoW)

Khi container **đọc** file → đọc thẳng từ image layer bên dưới, không copy.

Khi container **ghi** file → file được **copy lên write layer** trước, rồi mới sửa. Image layer gốc không bao giờ bị thay đổi.

```
Container sửa /etc/nginx/nginx.conf:
1. OverlayFS copy file từ image layer lên write layer
2. Container sửa bản copy ở write layer
3. Image layer gốc vẫn nguyên vẹn

→ Container khác chạy từ cùng image vẫn thấy nginx.conf gốc
```

### Hệ quả quan trọng

Write layer **bị xóa khi container bị xóa**. Mọi thay đổi trong container (log files, uploaded files, database data) đều mất nếu không dùng Volume.

```bash
# Minh chứng: tạo file trong container rồi xóa container
docker run --name test nginx bash -c "echo hello > /tmp/myfile.txt"
docker rm test
docker run --name test2 nginx bash -c "cat /tmp/myfile.txt"
# → cat: /tmp/myfile.txt: No such file or directory
```

---

## Tóm tắt 3 cơ chế

| Cơ chế | Kernel feature | Làm gì |
|--------|---------------|--------|
| **Namespaces** | clone() flags | Cô lập: PID, network, filesystem, hostname |
| **cgroups** | cgroupfs | Giới hạn: CPU, RAM, I/O, processes |
| **OverlayFS** | overlay module | Layer filesystem, copy-on-write |

Ba thứ này kết hợp lại tạo ra ảo giác "máy tính riêng" — nhưng thực tế chỉ là các processes Linux với nhiều giới hạn và trick được áp dụng.

---

**Tiếp theo:** [04_dockerfile.md](./04_dockerfile.md) — Viết Dockerfile và hiểu build cache.
