# 02 — Container Orchestration & Kubernetes

> Docker giải quyết "chạy một container". K8s giải quyết "chạy hàng nghìn containers".

---

## Vấn đề khi không có Orchestration

Giả sử app của bạn có 10 services, mỗi service chạy 5 containers — tổng cộng 50 containers trên nhiều server. Bây giờ:

- Container bị crash lúc 3 giờ sáng → ai restart?
- Traffic tăng đột biến → scale thêm container thế nào?
- Deploy version mới → cập nhật từng container thủ công?
- Server chết → containers trên đó ai chuyển sang server khác?

Làm thủ công thì không thể. Đây chính là bài toán **Orchestration** giải quyết.

---

## Orchestration là gì?

Orchestration là hệ thống **tự động hóa** việc:

| Nhiệm vụ | Không có Orchestration | Có K8s |
|----------|----------------------|--------|
| Container crash | Tự restart thủ công | Tự động restart |
| Scale up/down | SSH vào từng server | Thay 1 con số |
| Deploy mới | Downtime hoặc kịch bản phức tạp | Rolling update zero-downtime |
| Server chết | Di chuyển containers thủ công | Tự reschedule sang server khác |
| Health check | Script tự viết | Built-in Probes |
| Load balancing | Cấu hình nginx thủ công | Built-in Service |

---

## Kubernetes là gì?

Kubernetes (K8s) là **container orchestration platform** mã nguồn mở, ban đầu do Google phát triển từ kinh nghiệm vận hành Borg — hệ thống chạy hàng tỷ containers của họ. Hiện được CNCF (Cloud Native Computing Foundation) duy trì.

K8s không thay thế Docker. K8s **dùng** Docker (hoặc containerd) để chạy containers, nhưng tự lo toàn bộ việc scheduling, scaling, healing.

---

## K8s Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      K8s Cluster                            │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                  Control Plane                       │   │
│  │                                                      │   │
│  │  ┌──────────┐  ┌──────────┐  ┌────────────────────┐ │   │
│  │  │  API     │  │  etcd    │  │  Controller Manager │ │   │
│  │  │  Server  │  │ (DB)     │  │  (reconcile loop)  │ │   │
│  │  └──────────┘  └──────────┘  └────────────────────┘ │   │
│  │                                                      │   │
│  │  ┌──────────┐                                        │   │
│  │  │Scheduler │  (quyết định Pod chạy trên Node nào)  │   │
│  │  └──────────┘                                        │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Worker     │  │   Worker     │  │   Worker     │      │
│  │   Node 1     │  │   Node 2     │  │   Node 3     │      │
│  │              │  │              │  │              │      │
│  │  ┌────────┐  │  │  ┌────────┐  │  │  ┌────────┐  │      │
│  │  │kubelet │  │  │  │kubelet │  │  │  │kubelet │  │      │
│  │  └────────┘  │  │  └────────┘  │  │  └────────┘  │      │
│  │  Pod Pod Pod │  │  Pod Pod     │  │  Pod Pod Pod │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

### Control Plane — "Bộ não"

**API Server** — Cổng vào duy nhất của cluster. Mọi lệnh `kubectl` đều gửi đến đây. Stateless — có thể chạy nhiều replicas.

**etcd** — Database phân tán lưu toàn bộ trạng thái cluster (key-value store). Đây là "source of truth" — mất etcd là mất cluster. Phải backup thường xuyên.

**Controller Manager** — Chạy các vòng lặp liên tục so sánh "trạng thái hiện tại" vs "trạng thái mong muốn" và tự điều chỉnh. Ví dụ: bạn muốn 3 replicas, hiện chỉ có 2 → Controller tạo thêm 1.

**Scheduler** — Nhìn vào các Pod chưa được gán Node và quyết định Pod nên chạy trên Node nào dựa trên resources còn trống, constraints, affinity rules.

### Worker Node — "Cơ bắp"

**kubelet** — Agent chạy trên mỗi Node, nhận lệnh từ API Server và đảm bảo containers đang chạy đúng theo spec.

**kube-proxy** — Quản lý network rules trên Node, implement phần của Service abstraction.

**Container Runtime** — Thực sự chạy containers (containerd, CRI-O, hoặc Docker).

---

## Declarative Model — Triết lý cốt lõi của K8s

K8s theo mô hình **declarative** giống Terraform — bạn mô tả trạng thái mong muốn, K8s tự tìm cách đạt được và duy trì nó.

```yaml
# Bạn nói: "Tôi muốn 3 replicas của nginx"
apiVersion: apps/v1
kind: Deployment
spec:
  replicas: 3          # ← trạng thái mong muốn
  template:
    spec:
      containers:
      - image: nginx:1.25
```

K8s sau đó:
1. Tạo 3 Pods
2. Nếu 1 Pod crash → tự tạo lại
3. Nếu Node chết → reschedule Pods sang Node khác
4. Mãi mãi reconcile cho đến khi đúng 3 replicas

Bạn không bao giờ nói "hãy tạo Pod thứ 3" — bạn chỉ nói "tôi muốn 3".

---

## Managed K8s vs Self-hosted

| | Self-hosted | Managed (EKS/GKE/AKS) |
|-|-------------|----------------------|
| **Control Plane** | Bạn tự quản lý | Cloud provider lo |
| **Upgrade** | Thủ công, phức tạp | 1 click |
| **Chi phí** | Thấp hơn | Cao hơn (trả phí management) |
| **Phù hợp** | On-premise, learning | Production trên cloud |

Khi mới học: dùng **minikube** (local) hoặc **kind** (K8s in Docker). Khi lên production trên AWS: dùng **EKS**.

---

## Kiểm tra hiểu biết

1. etcd đóng vai trò gì trong cluster? Tại sao phải backup?
2. Controller Manager làm gì liên tục?
3. Sự khác nhau giữa Control Plane và Worker Node?

---

**Tiếp theo:** [03_pod.md](./03_pod.md) — Pod, đơn vị nhỏ nhất trong K8s.
