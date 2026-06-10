# 04 — Grafana & Loki: Visualize và Log Management

> **Mục tiêu:** Hiểu cách dùng Grafana để tạo dashboard và Loki để query logs.

---

## 🎨 Grafana là gì?

Grafana là nền tảng **visualization và analytics** mã nguồn mở. Nó không lưu trữ data mà **kết nối với nhiều data source** và hiển thị dashboard.

```
Grafana là "cửa sổ nhìn vào hệ thống":

┌─────────────────────────────────────────────────────────┐
│                     GRAFANA UI                          │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   Metrics    │  │    Logs      │  │   Traces     │  │
│  │   Panel      │  │   Panel      │  │   Panel      │  │
│  │  (PromQL)    │  │  (LogQL)     │  │  (TraceQL)   │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
        │                   │                   │
        ▼                   ▼                   ▼
   Prometheus            Loki               Tempo/Jaeger
   (Metrics DB)        (Log DB)            (Trace DB)
```

---

## 🏗️ Grafana Data Sources phổ biến

```
Grafana hỗ trợ 100+ data sources:

┌─────────────────────────────────────────────────────────┐
│                                                         │
│  Metrics:    Prometheus, InfluxDB, CloudWatch           │
│  Logs:       Loki, Elasticsearch, CloudWatch Logs       │
│  Traces:     Tempo, Jaeger, Zipkin, X-Ray               │
│  Database:   MySQL, PostgreSQL, MongoDB                 │
│  Others:     GitHub, PagerDuty, Datadog, Splunk         │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 📊 Tạo Dashboard cơ bản

### Các loại panel thường dùng

```
TIME SERIES                    STAT (Single Number)
────────────────               ────────────────────
100 ┤    ╭──╮                  ┌──────────────────┐
 75 ┤  ╭─╯  ╰─╮               │                  │
 50 ┤──╯       ╰───            │    99.97%        │
    └───────────────           │   Availability   │
Dùng cho: RPS, latency         └──────────────────┘
theo thời gian                 Dùng cho: current SLI

GAUGE                          TABLE
────────────────               ────────────────────
    ╭───╮                      Service  | Errors | p99
   ╱     ╲                     ─────────────────────
  ╱  75%  ╲                    payment  |  0.1%  | 120ms
 ╱_________╲                   auth     |  0.0%  | 45ms
                               cart     |  0.3%  | 200ms
Dùng cho: error budget         Dùng cho: so sánh services
```

### Dashboard SLO cơ bản (JSON structure)

```json
{
  "dashboard": {
    "title": "SLO Overview — Payment Service",
    "panels": [
      {
        "title": "Availability SLI (last 30d)",
        "type": "stat",
        "targets": [{
          "expr": "sum(rate(http_requests_total{status!~'5..'}[30d])) / sum(rate(http_requests_total[30d]))",
          "legendFormat": "Availability"
        }],
        "thresholds": {
          "steps": [
            {"color": "red",   "value": 0},
            {"color": "yellow","value": 0.999},
            {"color": "green", "value": 0.9995}
          ]
        }
      },
      {
        "title": "Error Budget Remaining",
        "type": "gauge",
        "targets": [{
          "expr": "1 - (sum(rate(http_requests_total{status=~'5..'}[30d])) / sum(rate(http_requests_total[30d]))) / 0.001"
        }]
      }
    ]
  }
}
```

---

## 📝 Loki — Log Aggregation

### Loki là gì?

Loki là hệ thống **log aggregation** được thiết kế để hoạt động giống Prometheus nhưng dành cho logs.

```
Sự khác biệt Loki vs Elasticsearch:

LOKI                             ELASTICSEARCH
──────────────────────           ──────────────────────
✅ Index chỉ labels (nhẹ)        ❌ Index toàn bộ nội dung (nặng)
✅ Chi phí lưu trữ thấp          ❌ Chi phí cao
✅ Tích hợp tốt Grafana          ⚠️ Cần Kibana riêng
✅ Dùng labels như Prometheus    ❌ Khác biệt hoàn toàn
❌ Search full-text chậm hơn     ✅ Full-text search nhanh
❌ Không phân tích log content   ✅ Phân tích log phong phú
```

### Kiến trúc Loki

```
                        Applications
              ┌──────────────────────────────┐
              │  App A  │  App B  │  App C   │
              └──────────────────────────────┘
                              │
                              ▼
                     Promtail / Alloy
                  (Log Collector Agent)
                 Chạy trên mỗi node/pod
                              │
                              ▼ (push logs + labels)
              ┌───────────────────────────────┐
              │           LOKI                │
              │  ┌────────┐  ┌────────────┐  │
              │  │Distributor│ │  Ingester  │  │
              │  └────────┘  └────────────┘  │
              │  ┌──────────────────────────┐ │
              │  │  Object Storage (S3/GCS) │ │
              │  └──────────────────────────┘ │
              └───────────────────────────────┘
                              │
                              ▼
                           Grafana
                         (LogQL query)
```

---

## 🔍 LogQL — Ngôn ngữ query Loki

### Cú pháp cơ bản

```
{label_selector} | filter_expression | format_expression
```

### Ví dụ LogQL từ cơ bản đến nâng cao

```logql
# ─── LOG STREAM SELECTOR ──────────────────────────────────────

# Tất cả logs của service payment
{service="payment"}

# Nhiều điều kiện
{service="payment", env="production"}

# Regex
{service=~"payment.*"}


# ─── LOG FILTERS ──────────────────────────────────────────────

# Chứa chữ "error" (case-sensitive)
{service="payment"} |= "error"

# Không chứa "health"
{service="payment"} != "health"

# Regex match
{service="payment"} |~ "error|exception"


# ─── STRUCTURED LOG PARSING ───────────────────────────────────

# Parse JSON log
{service="payment"} | json

# Sau khi parse, filter theo field
{service="payment"} | json | level="ERROR"

# Filter theo multiple fields
{service="payment"} | json | level="ERROR" | status_code >= 500


# ─── METRIC QUERIES (đếm logs) ────────────────────────────────

# Đếm log errors mỗi phút
count_over_time({service="payment"} |= "error" [1m])

# Rate errors / giây
rate({service="payment"} | json | level="ERROR" [5m])

# Đếm theo label
sum by (level) (
  count_over_time({service="payment"} | json [5m])
)
```

---

## 🔗 Correlating Logs và Traces

Một trong những tính năng mạnh nhất: **Click từ log → xem trace ngay lập tức**

```
Workflow:
─────────────────────────────────────────────────────────
1. Thấy error trong Grafana dashboard
       │
       ▼
2. Mở Logs panel → thấy log error với trace_id="abc123"
       │
       ▼
3. Click vào trace_id → Grafana mở Tempo/Jaeger
       │
       ▼
4. Thấy toàn bộ trace: Payment Service gọi Bank API → timeout
       │
       ▼
5. Tìm ra nguyên nhân gốc rễ trong vài phút!
─────────────────────────────────────────────────────────
```

### Cấu hình derived field để link log → trace

```yaml
# Trong Grafana data source config cho Loki:
derivedFields:
  - name: "TraceID"
    matcherRegex: '"trace_id":"(\w+)"'
    url: "http://tempo:3200/trace/${__value.raw}"
    # Hoặc dùng data source link:
    datasourceUid: "tempo-uid"
    urlDisplayLabel: "View in Tempo"
```

---

## 🚨 Grafana Alerting

### Cấu hình alert từ Grafana (unified alerting)

```
Alert Rule Setup:
─────────────────────────────────────────────────────────

Bước 1: Chọn query
  PromQL: rate(http_requests_total{status=~"5.."}[5m])
        / rate(http_requests_total[5m]) > 0.01

Bước 2: Đặt conditions
  IS ABOVE 0.01 FOR 5 MINUTES

Bước 3: Cấu hình thông báo
  Contact Point: Slack #alerts-production
  Message: "🔴 Error rate {{ $values.A }}% trên {{ $labels.service }}"

Bước 4: Silence / Mute timing
  Maintenance window: Thứ 7 23:00 - 02:00
─────────────────────────────────────────────────────────
```

---

## 📦 Grafana Stack (LGTM)

```
Grafana Labs cung cấp bộ full stack:

L — Loki      (Logs)
G — Grafana   (Visualization)
T — Tempo     (Traces)
M — Mimir     (Metrics, compatible với Prometheus)

Deploy cùng nhau:
  helm install grafana-stack grafana/lgtm-distributed
```

---

## 🔗 Tài liệu tiếp theo

- **[05_burn_rate_alert.md](05_burn_rate_alert.md)** — Alert nâng cao với burn rate
- **[03_prometheus.md](03_prometheus.md)** — PromQL để query metrics
- Nguồn gốc: [Grafana Docs](https://grafana.com/docs/grafana/latest) | [Loki Docs](https://grafana.com/docs/loki/latest)
