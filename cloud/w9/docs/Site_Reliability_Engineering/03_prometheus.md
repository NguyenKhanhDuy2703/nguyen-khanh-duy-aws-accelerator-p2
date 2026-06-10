# 03 — Prometheus: Thu thập và Query Metrics

> **Mục tiêu:** Hiểu cách Prometheus hoạt động, cách viết PromQL, và tạo alerting rules.

---

## 🏛️ Prometheus là gì?

Prometheus là hệ thống **monitoring và alerting** mã nguồn mở, được thiết kế cho cloud-native applications.

```
Mô hình hoạt động của Prometheus (PULL model):

┌──────────────────────────────────────────────────────────┐
│                                                          │
│  Application A ──┐                                      │
│  /metrics        │                                      │
│                  │   Prometheus scrape (pull)           │
│  Application B ──┼──────────────────────► Prometheus   │
│  /metrics        │         ↑              Database      │
│                  │    mỗi 15s             (TSDB)        │
│  Application C ──┘                                      │
│  /metrics                                               │
│                                         ┌───────────────┤
│  Kubernetes Pods ────────────────────── │  PromQL       │
│  Node Exporter   ────────────────────── │  Query Engine │
│  cAdvisor        ────────────────────── └───────────────┤
│                                                 │       │
└─────────────────────────────────────────────────│───────┘
                                                  │
                                    ┌─────────────┴──────┐
                                    │   Alertmanager     │
                                    │   Grafana          │
                                    └────────────────────┘
```

> 💡 **PULL model:** Prometheus chủ động đến lấy metrics từ app (ngược lại với Datadog agent push lên server). App chỉ cần expose endpoint `/metrics`.

---

## 📊 Metrics endpoint trông như thế nào?

```
# Truy cập: http://your-app:8080/metrics

# HELP http_requests_total Total number of HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",status="200"} 1234
http_requests_total{method="GET",status="404"} 56
http_requests_total{method="POST",status="200"} 789
http_requests_total{method="POST",status="500"} 12

# HELP http_request_duration_seconds Request duration
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{le="0.1"} 800
http_request_duration_seconds_bucket{le="0.3"} 1050
http_request_duration_seconds_bucket{le="1.0"} 1190
http_request_duration_seconds_bucket{le="+Inf"} 1200
http_request_duration_seconds_sum 145.3
http_request_duration_seconds_count 1200
```

---

## 🔍 PromQL — Ngôn ngữ query Prometheus

### Cú pháp cơ bản

```
metric_name{label="value", label2=~"regex.*"}[time_range]
```

### Các phép toán thường dùng

```promql
# ─── INSTANT QUERY (giá trị hiện tại) ─────────────────────────

# Lấy tất cả requests
http_requests_total

# Lọc theo label
http_requests_total{method="GET", status="200"}

# Regex: status bắt đầu bằng 5 (5xx errors)
http_requests_total{status=~"5.."}

# Loại trừ: status KHÔNG phải 200
http_requests_total{status!="200"}


# ─── RANGE QUERY (lấy data trong khoảng thời gian) ────────────

# 5 phút gần nhất
http_requests_total[5m]


# ─── FUNCTIONS ────────────────────────────────────────────────

# rate(): tốc độ tăng / giây (dùng với counter)
rate(http_requests_total[5m])
# → "bao nhiêu requests/giây trong 5 phút qua"

# irate(): tốc độ tức thời (nhạy hơn, dùng với spike)
irate(http_requests_total[5m])

# increase(): tổng tăng trong khoảng thời gian
increase(http_requests_total[1h])
# → "tổng requests trong 1 giờ qua"

# sum(): cộng tổng tất cả labels
sum(rate(http_requests_total[5m]))

# by(): nhóm theo label
sum(rate(http_requests_total[5m])) by (method)
# → tốc độ request nhóm theo method (GET, POST, ...)

# histogram_quantile(): tính percentile
histogram_quantile(0.99, 
  rate(http_request_duration_seconds_bucket[5m])
)
# → p99 latency trong 5 phút qua
```

---

## 📐 Công thức SLI với PromQL

### 1. Availability SLI

```promql
# Success rate (tỷ lệ request thành công)
sum(rate(http_requests_total{status!~"5.."}[5m]))
/
sum(rate(http_requests_total[5m]))

# Kết quả: 0.9997 = 99.97% availability
```

```
Phân tích công thức:
────────────────────────────────────────────────────────
Tử số:   rate(requests không phải 5xx trong 5 phút)
Mẫu số:  rate(tất cả requests trong 5 phút)

Kết quả: 0.0 → 1.0  (nhân 100 để ra %)
────────────────────────────────────────────────────────
```

### 2. Latency SLI (p99 < 300ms)

```promql
# Tỷ lệ requests hoàn thành dưới 300ms
histogram_quantile(0.99,
  sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
)

# Nếu kết quả < 0.3 → p99 latency < 300ms → SLI đạt
```

### 3. Error Rate SLI

```promql
# Tỷ lệ lỗi
sum(rate(http_requests_total{status=~"5.."}[5m]))
/
sum(rate(http_requests_total[5m]))

# Kết quả: 0.003 = 0.3% error rate
```

---

## ⚠️ Alerting Rules

### Cấu hình file `alert_rules.yaml`

```yaml
groups:
  - name: slo_alerts
    rules:
    
      # Alert 1: Error rate cao
      - alert: HighErrorRate
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[5m]))
          /
          sum(rate(http_requests_total[5m]))
          > 0.01
        for: 5m        # Phải kéo dài 5 phút mới alert
        labels:
          severity: warning
        annotations:
          summary: "Error rate cao: {{ $value | humanizePercentage }}"
          description: "Service {{ $labels.service }} có error rate vượt 1%"

      # Alert 2: Latency p99 cao
      - alert: HighLatencyP99
        expr: |
          histogram_quantile(0.99,
            sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
          ) > 0.5
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "P99 latency vượt 500ms"

      # Alert 3: Service down
      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.instance }} đang down"
```

### Vòng đời của Alert

```
INACTIVE                  PENDING                    FIRING
   │                          │                          │
   │  Condition đúng          │  Condition đúng          │
   │ ─────────────────────►   │  trong `for` duration   │
   │                          │ ─────────────────────►   │
   │                          │                          │
   │  Condition sai           │  Condition sai           │
   │ ◄─────────────────────   │ ◄─────────────────────   │
   │                          │                          │
```

---

## 🗄️ Cấu hình Prometheus cơ bản

```yaml
# prometheus.yml
global:
  scrape_interval: 15s      # Thu thập metrics mỗi 15 giây
  evaluation_interval: 15s  # Đánh giá alert rules mỗi 15 giây

rule_files:
  - "alert_rules.yaml"

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

scrape_configs:
  # Scrape chính Prometheus
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Scrape app của bạn
  - job_name: 'payment-service'
    static_configs:
      - targets: ['payment-svc:8080']
    metrics_path: '/metrics'

  # Auto-discover Kubernetes pods
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
```

---

## 🔢 Bảng tham khảo nhanh PromQL

| Mục đích | Query |
|---------|-------|
| RPS (requests/second) | `rate(http_requests_total[5m])` |
| Error rate | `rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])` |
| p50 latency | `histogram_quantile(0.5, rate(http_request_duration_seconds_bucket[5m]))` |
| p99 latency | `histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))` |
| Tổng requests theo method | `sum by (method) (rate(http_requests_total[5m]))` |
| CPU usage | `100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` |
| Memory usage % | `(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100` |

---

## 🔗 Tài liệu tiếp theo

- **[04_grafana_loki.md](04_grafana_loki.md)** — Visualize metrics trong Grafana
- **[05_burn_rate_alert.md](05_burn_rate_alert.md)** — Viết burn rate alert với PromQL
- **[08_analysis_template.md](08_analysis_template.md)** — Dùng PromQL trong Argo Rollouts
- Nguồn gốc: [Prometheus Docs](https://prometheus.io/docs)
