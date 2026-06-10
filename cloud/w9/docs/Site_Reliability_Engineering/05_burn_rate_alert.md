# 05 — Burn Rate Alert: Cảnh báo thông minh cho SLO

> **Mục tiêu:** Hiểu multi-window burn rate alerting — cách Google SRE alert khi Error Budget bị "đốt" quá nhanh.

---

## 🔥 Burn Rate là gì?

**Burn Rate** là tốc độ tiêu thụ Error Budget so với mức bình thường.

```
Burn Rate = (Tốc độ lỗi hiện tại) / (Tốc độ lỗi cho phép)

Ví dụ:
  SLO = 99.9%  →  Error Budget = 0.1%
  
  Nếu error rate hiện tại = 1%:
  Burn Rate = 1% / 0.1% = 10x

  Nghĩa là: Đang đốt budget nhanh gấp 10 lần bình thường!
```

### Tác động của từng mức Burn Rate

```
Burn Rate 1x (bình thường):
  ┌────────────────────────────────────────────────────────┐
  │ Budget 100% ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░  │
  │              Hết trong 30 ngày (bình thường)          │
  └────────────────────────────────────────────────────────┘

Burn Rate 6x (nhanh 6 lần):
  ┌────────────────────────────────────────────────────────┐
  │ Budget 100% ▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
  │              Hết trong ~5 ngày!                        │
  └────────────────────────────────────────────────────────┘

Burn Rate 14.4x (nguy hiểm):
  ┌────────────────────────────────────────────────────────┐
  │ Budget 100% ▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
  │              Hết trong ~50 giờ!                        │
  └────────────────────────────────────────────────────────┘

Burn Rate 36x (khủng hoảng):
  ┌────────────────────────────────────────────────────────┐
  │ Budget 100% ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
  │              Hết trong ~20 giờ!                        │
  └────────────────────────────────────────────────────────┘
```

---

## ❌ Vấn đề với alert đơn giản

```
Alert thông thường:
  IF error_rate > 1% THEN alert

Vấn đề 1: NHIỀU NOISE
─────────────────────
  Chỉ 1 phút error rate 5% rồi hết
  → Alert kêu ầm ĩ cho sự cố nhỏ
  → Oncall thức giữa đêm vô ích

Vấn đề 2: BỎ LỠ SỰ CỐ CHẬM
──────────────────────────────
  Error rate 0.2% kéo dài 2 tuần
  → Error rate dưới threshold → Không alert
  → Budget đã cạn 40% mà không ai biết!
  
Giải pháp: Multi-window Burn Rate Alert
```

---

## 🎯 Multi-Window, Multi-Burn-Rate Alert

Google SRE đề xuất dùng **2 cửa sổ thời gian** (window) cho mỗi mức alert:

```
Cấu trúc alert:
─────────────────────────────────────────────────────────────
| Mức alert  | Short window | Long window | Burn Rate | Khi |
|------------|--------------|-------------|-----------|-----|
| PAGE (khẩn)| 5 phút       | 1 giờ       | ≥ 14.4x   | Cả hai |
| PAGE       | 30 phút      | 6 giờ       | ≥ 6x      | Cả hai |
| TICKET     | 2 giờ        | 1 ngày      | ≥ 3x      | Cả hai |
| TICKET     | 6 giờ        | 3 ngày      | ≥ 1x      | Cả hai |
─────────────────────────────────────────────────────────────
```

### Tại sao cần 2 window?

```
Short window (5 phút):          Long window (1 giờ):
────────────────────────        ──────────────────────────────
Phát hiện nhanh                 Xác nhận đây là vấn đề thật
Dễ false positive               Giảm false positive

Cả hai phải ĐỒNG THỜI cao → Mới alert!
```

```
Ví dụ tình huống:

Tình huống A (False positive — không alert):
  Short window (5m): Burn rate = 20x ← cao!
  Long window (1h):  Burn rate = 0.5x ← thấp
  → CHỈ ngắn cao = spike nhất thời → Không page!

Tình huống B (Alert thật — phải page):
  Short window (5m): Burn rate = 16x ← cao!
  Long window (1h):  Burn rate = 15x ← cao!
  → Cả hai đều cao = sự cố thật → PAGE ngay!

Tình huống C (Slow burn — alert muộn hơn):
  Short window (2h): Burn rate = 4x ← trên ngưỡng 3x
  Long window (1d):  Burn rate = 3.5x ← trên ngưỡng 3x
  → Tạo ticket, không phải page đêm
```

---

## 📐 Tính toán Burn Rate

### Công thức

```
Burn Rate = error_rate_hiện_tại / error_rate_budget

Với SLO = 99.9% (error budget = 0.1% = 0.001):

Burn Rate = error_rate_hiện_tại / 0.001

Ví dụ:
  error_rate = 0.5% = 0.005
  Burn Rate = 0.005 / 0.001 = 5x
```

### Mối quan hệ Burn Rate → Thời gian cạn budget

```
Burn Rate  | Budget còn lại sau... | Cần alert không?
───────────┼───────────────────────┼─────────────────
1x         | 30 ngày               | Không
2x         | 15 ngày               | Không
3x         | 10 ngày               | Ticket
6x         | 5 ngày                | Page (giờ hành chính)
14.4x      | ~50 giờ               | Page (bất kỳ lúc nào)
36x        | ~20 giờ               | Page khẩn ngay!
```

---

## ⚙️ PromQL cho Multi-Window Burn Rate

### Công thức PromQL đầy đủ

```promql
# ─── BƯỚC 1: Tính error ratio ─────────────────────────────────

# Error ratio trong 5 phút
(
  sum(rate(http_requests_total{status=~"5.."}[5m]))
  /
  sum(rate(http_requests_total[5m]))
)

# Error ratio trong 1 giờ  
(
  sum(rate(http_requests_total{status=~"5.."}[1h]))
  /
  sum(rate(http_requests_total[1h]))
)


# ─── BƯỚC 2: Tính burn rate ───────────────────────────────────

# SLO error budget = 0.001 (cho SLO 99.9%)
# Burn rate 5m window:
(
  sum(rate(http_requests_total{status=~"5.."}[5m]))
  /
  sum(rate(http_requests_total[5m]))
) / 0.001

# Burn rate 1h window:
(
  sum(rate(http_requests_total{status=~"5.."}[1h]))
  /
  sum(rate(http_requests_total[1h]))
) / 0.001


# ─── BƯỚC 3: Alert rule ───────────────────────────────────────

# PAGE alert: Burn rate >= 14.4x trên CẢ 5m VÀ 1h window
(
  (
    sum(rate(http_requests_total{status=~"5.."}[5m]))
    / sum(rate(http_requests_total[5m]))
  ) / 0.001 >= 14.4
)
AND
(
  (
    sum(rate(http_requests_total{status=~"5.."}[1h]))
    / sum(rate(http_requests_total[1h]))
  ) / 0.001 >= 14.4
)
```

---

## 📋 Alert Rules YAML hoàn chỉnh

```yaml
groups:
  - name: slo_burn_rate
    rules:
    
      # ─── PAGE: Nguy hiểm cao (thức dậy ngay!) ───────────────
      - alert: SLOBurnRateCritical
        expr: |
          (
            (
              sum(rate(http_requests_total{status=~"5.."}[5m]))
              / sum(rate(http_requests_total[5m]))
            ) / 0.001 > 14.4
          )
          AND
          (
            (
              sum(rate(http_requests_total{status=~"5.."}[1h]))
              / sum(rate(http_requests_total[1h]))
            ) / 0.001 > 14.4
          )
        for: 2m
        labels:
          severity: page
          slo: availability
        annotations:
          summary: "🔴 SLO CRITICAL: Budget đốt nhanh gấp 14x"
          description: |
            Error budget sẽ cạn trong vòng 1 giờ.
            Burn rate hiện tại: {{ $value | humanize }}x
          runbook: "https://wiki.example.com/runbooks/high-error-rate"

      # ─── PAGE: Cảnh báo sớm (trong giờ làm việc) ────────────
      - alert: SLOBurnRateHigh
        expr: |
          (
            (
              sum(rate(http_requests_total{status=~"5.."}[30m]))
              / sum(rate(http_requests_total[30m]))
            ) / 0.001 > 6
          )
          AND
          (
            (
              sum(rate(http_requests_total{status=~"5.."}[6h]))
              / sum(rate(http_requests_total[6h]))
            ) / 0.001 > 6
          )
        for: 15m
        labels:
          severity: warning
          slo: availability
        annotations:
          summary: "🟡 SLO WARNING: Budget đốt nhanh gấp 6x"
          description: |
            Error budget sẽ cạn trong vòng 5 ngày.
            Cần xử lý trong giờ làm việc.

      # ─── TICKET: Vấn đề chậm nhưng cần theo dõi ─────────────
      - alert: SLOBurnRateSlow
        expr: |
          (
            (
              sum(rate(http_requests_total{status=~"5.."}[2h]))
              / sum(rate(http_requests_total[2h]))
            ) / 0.001 > 3
          )
          AND
          (
            (
              sum(rate(http_requests_total{status=~"5.."}[1d]))
              / sum(rate(http_requests_total[1d]))
            ) / 0.001 > 3
          )
        for: 1h
        labels:
          severity: ticket
          slo: availability
        annotations:
          summary: "🟢 SLO INFO: Tạo ticket — budget đốt nhanh gấp 3x"
```

---

## 🔄 Tổng kết Flow Alert

```
Error xảy ra trong hệ thống
           │
           ▼
    Prometheus thu thập
    error_rate metrics
           │
           ▼
    Tính burn rate
    (so với error budget)
           │
    ┌──────┴──────────────────────────────┐
    │                                     │
    ▼ Burn Rate ≥ 14.4x                  ▼ Burn Rate 6x-14x
    (cả 5m và 1h window)                 (cả 30m và 6h window)
    │                                     │
    ▼                                     ▼
  PAGE ALERT                          PAGE (giờ hành chính)
  PagerDuty / OpsGenie               Hoặc Slack notification
  Thức dậy ngay!                      Không cần thức đêm
```

---

## 🔗 Tài liệu tiếp theo

- **[06_progressive_delivery.md](06_progressive_delivery.md)** — Deploy an toàn để tránh bị burn rate!
- **[08_analysis_template.md](08_analysis_template.md)** — Tự động check burn rate trong canary deploy
- Nguồn gốc: [Google SRE Workbook — Alerting on SLOs](https://sre.google/workbook/alerting-on-slos)
