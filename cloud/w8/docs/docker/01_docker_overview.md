# 01 — Docker Là Gì và Vì Sao Nên Dùng

---

## Vấn đề trước khi có Docker

```
"Chạy được trên máy tôi mà!" — câu nói kinh điển của mọi developer
```

Nguyên nhân: mỗi môi trường (laptop dev, server staging, server prod) có phiên bản OS, runtime, thư viện khác nhau. App viết trên Python 3.9 + thư viện A v1.2, deploy lên server đang chạy Python 3.7 + thư viện A v0.9 → crash.

---

## Docker là gì?

Docker là **nền tảng đóng gói và chạy ứng dụng trong container** — một môi trường cô lập chứa đủ mọi thứ app cần: code, runtime, dependencies, config.

Một container chạy giống hệt nhau trên mọi máy có Docker — laptop dev, CI server, hay AWS EC2.

```
┌──────────────────────────────────────┐
│            Container                 │
│  ┌────────────────────────────────┐  │
│  │  App code (Python/Node/Go...)  │  │
│  ├────────────────────────────────┤  │
│  │  Runtime (Python 3.11)        │  │
│  ├────────────────────────────────┤  │
│  │  Thư viện (requests, flask...) │  │
│  ├────────────────────────────────┤  │
│  │  Biến môi trường, config       │  │
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘
   Chạy giống nhau trên MỌI máy
```

---

## Docker vs Virtual Machine

```
Virtual Machine                        Container
──────────────────────────────────     ──────────────────────────────────
[ App A  ]   [ App B  ]                [ App A ]  [ App B ]  [ App C ]
[ Libs A ]   [ Libs B ]                [ Libs A]  [ Libs B]  [ Libs C]
[ Guest OS ] [ Guest OS ]              └─────────────────────────────┘
[ Hypervisor (VMware/VBox) ]                  Container Runtime
[ Host OS                  ]                  [ Host OS (Linux) ]
[ Physical Hardware        ]                  [ Physical Hardware]
```

| Tiêu chí | VM | Container |
|----------|----|-----------| 
| Khởi động | Vài phút | Vài giây |
| Kích thước | GB (có full OS) | MB |
| Cô lập | Kernel riêng hoàn toàn | Share kernel host |
| Overhead | Cao | Gần native |
| Portability | Thấp (image nặng) | Cao (image nhẹ) |

> **Thực tế production:** VM và Container thường dùng cùng nhau — K8s nodes chạy trên EC2 (VM), containers chạy bên trong Node đó.

---

## Vì sao nên dùng Docker?

**1. Consistency** — "Build once, run anywhere". Không còn lỗi môi trường.

**2. Isolation** — Mỗi app chạy trong sandbox riêng. App A dùng Python 3.9, App B dùng Python 3.11, không conflict.

**3. Speed** — Khởi động container tính bằng giây, không phải phút như VM.

**4. Portability** — Push image lên registry, pull về bất kỳ đâu và chạy ngay.

**5. CI/CD** — Pipeline build → test → deploy đơn giản và lặp lại được.

**6. Microservices** — Mỗi service đóng gói riêng, deploy độc lập, scale độc lập.

---

## Các khái niệm cốt lõi

**Image** — Bản thiết kế (blueprint) read-only. Gồm nhiều layer chồng nhau. Không thay đổi sau khi build.

**Container** — Instance đang chạy từ Image. Có thêm một write layer ở trên cùng. Nhiều container có thể chạy từ cùng một image.

**Dockerfile** — File text chứa các lệnh để build Image.

**Registry** — Kho lưu trữ Image (Docker Hub, ECR, GCR...).

```
Dockerfile  →  docker build  →  Image  →  docker run  →  Container
                                  ↕
                               Registry
                          (docker push/pull)
```

---

**Tiếp theo:** [02_architecture.md](./02_architecture.md) — Bên trong Docker hoạt động thế nào.
