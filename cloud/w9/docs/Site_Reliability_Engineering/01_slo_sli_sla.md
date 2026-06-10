# 01 — SLO / SLI / SLA: Nền tảng tư duy SRE

> **Mục tiêu:** Hiểu SLI, SLO, SLA là gì và tại sao chúng quan trọng với mọi engineer.

---

## 🤔 Tại sao cần SLO/SLI/SLA?

Không có công ty nào đạt được uptime 100% mãi mãi. Vấn đề là:
- Bao nhiêu lỗi thì người dùng **chấp nhận được**?
- Khi nào thì **cần báo động**?
- Khi nào thì **có thể deploy** tính năng mới?

SLO/SLI/SLA giúp trả lời các câu hỏi này bằng **con số cụ thể**.

---

## 📐 Định nghĩa 3 khái niệm

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  SLA (Service Level Agreement)                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Hợp đồng với khách hàng (external commitment)  │   │
│  │  Ví dụ: "99.9% uptime / tháng, nếu không đạt   │   │
│  │         → hoàn tiền 10%"                        │   │
│  │                                                 │   │
│  │  SLO (Service Level Objective)                  │   │
│  │  ┌───────────────────────────────────────────┐  │   │
│  │  │  Mục tiêu nội bộ team (internal target)   │  │   │
│  │  │  Ví dụ: "99.95% uptime / tháng"           │  │   │
│  │  │  (cao hơn SLA để có buffer)               │  │   │
│  │  │                                           │  │   │
│  │  │  SLI (Service Level Indicator)            │  │   │
│  │  │  ┌─────────────────────────────────────┐  │  │   │
│  │  │  │  Số đo thực tế từ hệ thống          │  │   │   │
│  │  │  │  Ví dụ: "99.97% requests thành công"│  │  │   │
│  │  │  └─────────────────────────────────────┘  │  │   │
│  │  └───────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

| Thuật ngữ | Tiếng Việt | Ai quan tâm | Ví dụ |
|-----------|-----------|-------------|-------|
| **SLI** | Chỉ số đo lường | Engineer | 99.97% success rate |
| **SLO** | Mục tiêu nội bộ | Team / Manager | ≥ 99.95% |
| **SLA** | Cam kết hợp đồng | Business / Khách hàng | ≥ 99.9% |

> 💡 **Quy tắc vàng:** `SLA < SLO ≤ SLI thực tế`  
> SLO phải **chặt hơn SLA** để bạn có thời gian phản ứng trước khi vi phạm hợp đồng.

---

## 📊 Ví dụ thực tế: API Payment Service

### Bước 1 — Chọn SLI phù hợp

```
Loại SLI phổ biến:

  Availability SLI:
  ─────────────────
  good_requests
  ─────────────  × 100%
  total_requests

  Latency SLI:
  ─────────────────────────────────────────
  requests_under_300ms
  ────────────────────  × 100%
  total_requests

  Error Rate SLI:
  ─────────────────────────────────────────
  1 - (error_requests / total_requests)
```

### Bước 2 — Đặt SLO

```yaml
# Ví dụ SLO cho Payment API
SLOs:
  - name: availability
    target: 99.9%           # 43.8 phút downtime/tháng được phép
    window: 30 ngày

  - name: latency_p99
    target: 95%             # 95% requests dưới 300ms
    threshold: 300ms
    window: 30 ngày

  - name: error_rate
    target: 99.5%           # Tối đa 0.5% requests lỗi
    window: 30 ngày
```

---

## 🪣 Error Budget — Ngân sách lỗi

Error Budget là **lượng lỗi được phép** trước khi vi phạm SLO.

```
Error Budget = 100% - SLO target

Ví dụ với SLO = 99.9%:
  Error Budget = 100% - 99.9% = 0.1%

  Trong 30 ngày (43,200 phút):
  ┌────────────────────────────────────────────────┐
  │  0.1% × 43,200 phút = 43.2 phút downtime/tháng│
  └────────────────────────────────────────────────┘
```

### Cách dùng Error Budget

```
Error Budget còn nhiều          Error Budget cạn
        │                              │
        ▼                              ▼
  ✅ Deploy thoải mái          ⛔ Dừng deploy mới
  ✅ Thử nghiệm tính năng      ✅ Tập trung sửa lỗi
  ✅ Chấp nhận rủi ro cao      ✅ Cải thiện reliability
```

### Vòng đời Error Budget trong tháng

```
100% ┤
     │▓▓▓▓▓▓▓▓▓▓▓▓ (budget còn)
     │
 50% ┤▓▓▓▓▓░░░░░░░ (đang dùng dần)
     │
 20% ┤▓▓░░░░░░░░░░ ← CẢNH BÁO: Chậm lại!
     │
  0% ┤░░░░░░░░░░░░ ← ĐÓNG BĂNG: Không deploy!
     └─────────────────────────────────────
     Ngày 1                         Ngày 30
```

---

## 🎯 Chọn SLI đúng: Những sai lầm phổ biến

```
❌ Sai: Monitor server CPU, RAM
   → Đây là resource, không phải trải nghiệm người dùng

✅ Đúng: Monitor request success rate, latency
   → Đây là thứ người dùng thực sự cảm nhận

❌ Sai: SLO = 100% uptime
   → Không thực tế, tốn chi phí khổng lồ, không thể đạt

✅ Đúng: SLO = 99.9% với error budget rõ ràng
   → Có thể đo, có thể cải thiện

❌ Sai: Đặt SLO xong rồi quên
   → SLO phải được review theo quý

✅ Đúng: SLO sống động, điều chỉnh theo user feedback
   → Nếu user không phàn nàn dù vi phạm → SLO quá chặt
   → Nếu user phàn nàn khi chưa vi phạm → SLO quá lỏng
```

---

## 📋 Checklist: Tạo SLO đầu tiên

```
□ 1. Xác định "what does good look like" cho user
□ 2. Chọn SLI đo được từ hệ thống (metrics)
□ 3. Đặt SLO target thực tế (dựa trên historical data)
□ 4. Tính Error Budget tương ứng
□ 5. Quyết định policy: Khi nào thì freeze deploy?
□ 6. Tạo dashboard theo dõi SLI vs SLO
□ 7. Review sau 1 tháng và điều chỉnh
```

---

## 🔗 Tài liệu tiếp theo

- **[02_opentelemetry.md](02_opentelemetry.md)** — Làm sao thu thập SLI data từ app?
- **[05_burn_rate_alert.md](05_burn_rate_alert.md)** — Alert khi Error Budget cạn nhanh
- Nguồn gốc: [Google SRE Book — SLO Chapter](https://sre.google/sre-book/service-level-objectives)
