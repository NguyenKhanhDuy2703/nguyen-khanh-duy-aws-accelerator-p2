# 01 — Infrastructure as Code (IaC) Overview

> Hiểu tại sao IaC ra đời và Terraform phù hợp với bạn như thế nào.

---

## IaC là gì?

**Infrastructure as Code** là phương pháp quản lý và cung cấp hạ tầng (server, network, database...) thông qua **code** thay vì thao tác thủ công qua giao diện web (console).

Thay vì click-click trên AWS Console để tạo EC2, bạn viết một file mô tả "tôi cần một máy chủ loại t3.micro, OS Amazon Linux, thuộc VPC này..." và để tool tự làm phần còn lại.

### Trước khi có IaC (ClickOps)

```
Developer → AWS Console → Click tạo EC2 → Click tạo Security Group
           → Nhớ miệng những gì đã làm → Lặp lại cho môi trường mới
```

Vấn đề:
- Không tái tạo lại được chính xác (snowflake servers)
- Không có lịch sử thay đổi (ai sửa cái gì, khi nào?)
- Scale lên nhiều môi trường (dev/staging/prod) rất tốn công

### Sau khi có IaC

```
Developer → Viết code → Commit vào Git → Pipeline tự deploy
           → Môi trường mới = clone code → Thay đổi = PR review
```

---

## Lợi ích cốt lõi

**Idempotency** — Chạy cùng một code nhiều lần vẫn cho ra kết quả giống nhau. Không bao giờ tạo ra resource thừa.

**Version control** — Toàn bộ hạ tầng sống trong Git. Muốn biết ai thêm cái database từ 3 tháng trước? `git log`.

**Reproducibility** — Môi trường dev và prod được tạo từ cùng một code. Lỗi "chạy được trên local mà không chạy được trên prod" liên quan đến infra gần như biến mất.

**Automation** — Tích hợp vào CI/CD pipeline. Merge PR → hạ tầng tự cập nhật.

**Documentation** — Code chính là tài liệu. Đọc file `.tf` là biết ngay hạ tầng trông như thế nào.

---

## Các loại IaC tools

### Declarative vs Imperative

| Cách tiếp cận | Bạn nói gì | Ví dụ |
|---------------|-----------|-------|
| **Declarative** | "Tôi muốn kết quả như này" | Terraform, CloudFormation, Pulumi |
| **Imperative** | "Làm theo các bước này" | Ansible (phần config), shell scripts |

Terraform theo hướng **declarative** — bạn mô tả trạng thái mong muốn, Terraform tự tìm ra cách đạt được nó.

### So sánh các tools phổ biến

| Tool | Hãng | Ngôn ngữ | Phù hợp |
|------|------|----------|---------|
| **Terraform** | HashiCorp | HCL | Multi-cloud, phổ biến nhất |
| **OpenTofu** | Community | HCL | Fork open-source của Terraform |
| **Pulumi** | Pulumi Corp | Python/TS/Go | Developer-first, code thật |
| **CloudFormation** | AWS | YAML/JSON | AWS only, native |
| **CDK** | AWS | Python/TS/Java | AWS only, code hơn CF |
| **Ansible** | Red Hat | YAML | Config management, ít dùng cho infra |

### Khi nào dùng Terraform?

Chọn Terraform khi:
- Cần quản lý nhiều cloud provider cùng lúc (AWS + GCP + Azure)
- Team đã quen với HCL hoặc muốn ecosystem lớn (modules, registry)
- Muốn state management rõ ràng

Chọn Pulumi khi đội ngũ là developer thuần túy và muốn dùng ngôn ngữ lập trình thật (Python, TypeScript).

---

## Terraform hoạt động như thế nào?

```
┌─────────────────────────────────────────────────────┐
│                   Terraform Core                    │
│                                                     │
│  .tf files  →  Plan (diff)  →  Apply (API calls)   │
└─────────────────────┬───────────────────────────────┘
                      │  gọi qua providers
          ┌───────────┼───────────┐
          ▼           ▼           ▼
      AWS API     GCP API    Azure API
```

**Providers** là plugin kết nối Terraform với từng cloud/service. Có hàng nghìn providers trên [Terraform Registry](https://registry.terraform.io) — từ AWS, GCP, Azure cho đến GitHub, Datadog, PagerDuty.

**State** là file Terraform dùng để nhớ "hiện tại hạ tầng đang ở trạng thái nào" (chi tiết ở file 04).

---

## Điểm khác biệt quan trọng: Terraform vs OpenTofu

Năm 2023, HashiCorp đổi license Terraform sang BSL (Business Source License) — không còn hoàn toàn open-source. Cộng đồng tạo **OpenTofu** là fork open-source 100%. Cú pháp và cách dùng gần như giống hệt nhau. Tài liệu này dùng Terraform nhưng kiến thức áp dụng được cho cả hai.

---

## Kiểm tra hiểu biết

Sau phần này bạn nên trả lời được:

1. IaC giải quyết vấn đề gì của "ClickOps"?
2. Sự khác nhau giữa declarative và imperative là gì?
3. Terraform biết trạng thái hạ tầng hiện tại từ đâu?

---

