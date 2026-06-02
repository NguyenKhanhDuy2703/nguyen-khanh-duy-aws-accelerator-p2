# Docker — Tóm tắt kiến thức

> Tổng hợp toàn bộ nội dung Docker đã học — từ khái niệm đến thực hành.

---

## Cấu trúc tài liệu

| File | Nội dung | Thời gian ôn |
|------|----------|--------------|
| [01_docker_overview.md](./01_docker_overview.md) | Docker là gì, vì sao dùng, so sánh VM | 15 phút |
| [02_architecture.md](./02_architecture.md) | Client, Daemon, containerd, runc — luồng hoạt động | 20 phút |
| [03_inside_container.md](./03_inside_container.md) | Namespaces, cgroups, Union Filesystem | 20 phút |
| [04_dockerfile.md](./04_dockerfile.md) | Dockerfile instructions, build cache | 20 phút |
| [05_cli_and_registry.md](./05_cli_and_registry.md) | Lệnh Docker CLI, flags, pull/push, Docker Hub | 20 phút |
| [06_volumes.md](./06_volumes.md) | Volume, bind mount, tmpfs, data persistence | 15 phút |

**Tổng ôn tập:** ~2 giờ

---

## Cài đặt nhanh

```bash
# macOS
brew install --cask docker
# Sau đó mở Docker Desktop

# Kiểm tra
docker version
docker info

# Hello world
docker run hello-world
```

## Tài nguyên

- [Docker Docs](https://docs.docker.com) — tài liệu chính thống
- [Docker Hub](https://hub.docker.com) — registry public
- [Play with Docker](https://labs.play-with-docker.com) — lab online miễn phí
