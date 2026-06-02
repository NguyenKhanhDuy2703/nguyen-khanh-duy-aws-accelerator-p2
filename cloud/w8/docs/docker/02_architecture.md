# 02 — Kiến Trúc Docker

> Client gọi Daemon, Daemon dùng containerd, containerd dùng runc để thực sự tạo container.

---

## Tổng quan kiến trúc

Docker theo mô hình **client-server**. Client và Daemon có thể chạy trên cùng một máy (thông thường) hoặc khác máy (remote Docker host).

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Docker Host                                 │
│                                                                     │
│  ┌──────────────────┐        ┌──────────────────────────────────┐   │
│  │   Docker CLIENT  │        │         Docker DAEMON            │   │
│  │                  │        │         (dockerd)                │   │
│  │  ┌────────────┐  │        │                                  │   │
│  │  │ Docker CLI │  │──REST──▶  ┌──────────────────────────┐   │   │
│  │  │(docker run)│  │  API   │  │      containerd          │   │   │
│  │  └────────────┘  │        │  │  (container lifecycle)   │   │   │
│  │                  │        │  │                          │   │   │
│  │  ┌────────────┐  │        │  │  ┌────────┐ ┌────────┐  │   │   │
│  │  │Docker SDK  │  │        │  │  │ runc   │ │ runc   │  │   │   │
│  │  │(Python, Go)│  │        │  │  │(cont.1)│ │(cont.2)│  │   │   │
│  │  └────────────┘  │        │  └──────────────────────────┘   │   │
│  └──────────────────┘        └──────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                          │
                                          │ pull/push
                                          ▼
                                   ┌─────────────┐
                                   │  Registry   │
                                   │ (Docker Hub)│
                                   └─────────────┘
```

---

## Các thành phần chi tiết

### Docker Client — 2 loại

**Docker CLI** (`docker`) — công cụ dòng lệnh mà bạn gõ hàng ngày.
```bash
docker run nginx
docker build -t myapp .
docker ps
```

**Docker SDK** — thư viện lập trình để gọi Docker API từ code. Có bản Python, Go, Java... Dùng trong automation, CI/CD tools, monitoring agents.
```python
import docker
client = docker.from_env()
client.containers.run("nginx", detach=True)
```

Cả hai đều giao tiếp với Daemon qua **REST API** — mặc định qua Unix socket `/var/run/docker.sock`, hoặc TCP nếu remote.

---

### Docker Daemon (`dockerd`) — "Bộ não"

Tiến trình chạy nền, lắng nghe Docker API và điều phối mọi thứ:
- Nhận lệnh từ Client
- Quản lý Images (pull, build, cache)
- Gọi containerd để tạo/dừng/xóa container
- Quản lý network và volume

---

### containerd — Container Runtime cấp cao

Daemon độc lập, chịu trách nhiệm **lifecycle của container**:
- Pull image từ registry và giải nén
- Quản lý storage (snapshot của image layers)
- Quản lý network namespace
- Gọi runc để thực sự tạo container

> containerd ban đầu là một phần của Docker, sau được tách ra thành project độc lập và donate cho CNCF. K8s hiện cũng dùng containerd trực tiếp mà không cần Docker.

---

### runc — Container Runtime cấp thấp

Công cụ nhỏ nhất, làm đúng một việc: **tạo và chạy container** bằng cách gọi Linux kernel API (namespaces + cgroups). Tuân thủ OCI (Open Container Initiative) specification.

runc không biết về image, không biết về network — nó chỉ nhận một "bundle" (thư mục chứa filesystem + config) và tạo container từ đó.

---

## Luồng hoạt động: `docker run nginx`

```
Bước 1: docker run nginx
   │
   ▼
Bước 2: Docker CLI gửi POST /containers/create đến dockerd qua REST API
   │
   ▼
Bước 3: dockerd kiểm tra image "nginx" có trong local cache chưa?
   │       Chưa có → gọi containerd pull image từ Docker Hub
   │       Có rồi  → dùng luôn
   ▼
Bước 4: containerd giải nén image layers thành overlay filesystem
   │     (mount các read-only layers + tạo write layer mới)
   ▼
Bước 5: containerd tạo OCI bundle (config.json + rootfs/)
   │
   ▼
Bước 6: containerd gọi runc với bundle đó
   │
   ▼
Bước 7: runc gọi Linux kernel:
   │     - clone() với các namespace flags (PID, NET, MNT, UTS, IPC)
   │     - cgroups setup (giới hạn CPU, RAM)
   │     - chroot vào rootfs
   │     - exec process chính (nginx)
   ▼
Bước 8: Container đang chạy!
         runc exit (container không phụ thuộc vào runc nữa)
         containerd theo dõi tiến trình
         dockerd báo lại cho Client
```

---

## Tại sao tách nhiều lớp như vậy?

**Modularity** — Có thể thay thế từng layer độc lập. K8s bỏ Docker nhưng vẫn giữ containerd. Một runtime khác (gVisor, Kata Containers) có thể thay runc.

**Separation of concerns** — CLI không cần biết cách tạo container. Daemon không cần biết kernel syscall. Mỗi layer làm đúng một việc.

**OCI Standard** — runc implement OCI Runtime Spec, containerd implement OCI Image Spec. Bất kỳ tool nào tuân thủ OCI đều tương thích với nhau.

---

**Tiếp theo:** [03_inside_container.md](./03_inside_container.md) — Bên trong container có gì: namespaces, cgroups, union filesystem.
