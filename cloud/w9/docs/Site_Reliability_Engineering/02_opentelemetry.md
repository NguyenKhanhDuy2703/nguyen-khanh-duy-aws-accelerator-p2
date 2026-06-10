# 02 — OpenTelemetry (OTel): Thu thập dữ liệu quan sát

> **Mục tiêu:** Hiểu OTel là gì, 3 loại dữ liệu (Traces/Metrics/Logs), và cách instrument app.

---

## 🔭 OpenTelemetry là gì?

OpenTelemetry (OTel) là **bộ công cụ mã nguồn mở, vendor-neutral** giúp thu thập dữ liệu observability từ ứng dụng của bạn.

```
Trước OTel (vấn đề):            Sau OTel (giải pháp):
──────────────────               ──────────────────────
App → Datadog SDK   ←→  Datadog  App → OTel SDK → Datadog
App → Jaeger SDK    ←→  Jaeger              └──→ Jaeger
App → NewRelic SDK  ←→  NewRelic            └──→ NewRelic
(mỗi vendor 1 SDK khác nhau)   (1 SDK duy nhất, nhiều backend)
```

> 💡 **Giống như USB-C:** Một chuẩn kết nối với mọi thiết bị.

---

## 🧩 3 Trụ cột của Observability (Observability Pillars)

```
                    ┌─────────────────────────────────────────┐
                    │          OBSERVABILITY                  │
                    │                                         │
    ┌───────────────┼───────────────┬─────────────────────┐  │
    │               │               │                     │  │
    ▼               ▼               ▼                     │  │
┌────────┐    ┌──────────┐    ┌──────────┐               │  │
│ TRACES │    │ METRICS  │    │  LOGS    │               │  │
│        │    │          │    │          │               │  │
│"Luồng  │    │"Con số   │    │"Nhật ký  │               │  │
│request │    │theo thời │    │sự kiện"  │               │  │
│đi qua  │    │gian"     │    │          │               │  │
│đâu?"   │    │          │    │          │               │  │
└────────┘    └──────────┘    └──────────┘               │  │
    │               │               │                     │  │
    ▼               ▼               ▼                     │  │
  Jaeger        Prometheus        Loki                    │  │
  Tempo         VictoriaMetrics   Elasticsearch           │  │
    └───────────────┴───────────────┘                     │  │
                    │                                      │  │
                    ▼                                      │  │
                 Grafana (Visualize tất cả)                │  │
                    └──────────────────────────────────────┘  │
                                                              │
                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 1️⃣ TRACES — Theo dõi luồng request

**Trace** là bản ghi toàn bộ hành trình của 1 request qua hệ thống.

```
User gọi API: GET /checkout
│
├── [Span] API Gateway         (5ms)
│   └── [Span] Auth Service    (12ms)  ← chậm!
│       └── [Span] DB Query    (10ms)
│
├── [Span] Cart Service        (8ms)
│   └── [Span] Redis Cache     (1ms)
│
└── [Span] Payment Service     (45ms)  ← chậm nhất!
    ├── [Span] Validate Card   (3ms)
    └── [Span] Bank API Call   (40ms)  ← bottleneck!

Tổng: 70ms
```

### Khái niệm quan trọng

| Thuật ngữ | Nghĩa |
|-----------|-------|
| **Trace** | Toàn bộ hành trình 1 request |
| **Span** | 1 đơn vị công việc trong trace |
| **Trace ID** | ID duy nhất cho cả trace |
| **Span ID** | ID duy nhất cho 1 span |
| **Parent Span** | Span gọi span khác |
| **Context Propagation** | Truyền Trace ID qua các service |

### Ví dụ code instrument trace (Python)

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider

# Setup
provider = TracerProvider()
trace.set_tracer_provider(provider)
tracer = trace.get_tracer(__name__)

# Sử dụng trong code
def process_payment(user_id, amount):
    with tracer.start_as_current_span("process_payment") as span:
        span.set_attribute("user.id", user_id)
        span.set_attribute("payment.amount", amount)
        
        result = call_bank_api(amount)
        span.set_attribute("payment.status", result.status)
        return result
```

---

## 2️⃣ METRICS — Đo lường theo thời gian

**Metrics** là các con số được thu thập định kỳ để theo dõi sức khỏe hệ thống.

### 4 loại Metric trong OTel/Prometheus

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  COUNTER (Bộ đếm)                                          │
│  ──────────────────────────────────────────────────────    │
│  Chỉ tăng, không giảm                                      │
│  VD: http_requests_total, errors_total                      │
│                                                             │
│  100 ┤          ╭──────────────                            │
│   50 ┤    ╭─────╯                                          │
│    0 ┤────╯                                                │
│      └────────────────────────────────                     │
│                                                             │
│  GAUGE (Thước đo hiện tại)                                 │
│  ──────────────────────────────────────────────────────    │
│  Có thể tăng hoặc giảm                                     │
│  VD: memory_usage, active_connections, temperature          │
│                                                             │
│  100 ┤  ╭──╮    ╭──╮                                      │
│   50 ┤──╯  ╰────╯  ╰──                                    │
│    0 ┤                                                     │
│      └────────────────────────────────                     │
│                                                             │
│  HISTOGRAM (Phân phối giá trị)                             │
│  ──────────────────────────────────────────────────────    │
│  Nhóm giá trị vào các bucket, tính p50/p95/p99             │
│  VD: http_request_duration_seconds                          │
│                                                             │
│  bucket[<100ms]:  ████████████  (60%)                      │
│  bucket[<300ms]:  █████████     (45%)                      │
│  bucket[<1s]:     ████          (20%)                      │
│  bucket[<3s]:     █             (5%)                        │
│                                                             │
│  SUMMARY (Tóm tắt phân vị)                                 │
│  ──────────────────────────────────────────────────────    │
│  Tính percentile phía client                               │
│  VD: go_gc_duration_seconds (dùng trong Prometheus SDK)    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Ví dụ code instrument metric (Go)

```go
import "go.opentelemetry.io/otel/metric"

// Tạo counter
requestCounter, _ := meter.Int64Counter(
    "http.requests.total",
    metric.WithDescription("Total HTTP requests"),
)

// Tạo histogram
latencyHistogram, _ := meter.Float64Histogram(
    "http.request.duration",
    metric.WithUnit("ms"),
)

// Sử dụng trong handler
func handler(w http.ResponseWriter, r *http.Request) {
    start := time.Now()
    requestCounter.Add(ctx, 1, attribute.String("method", r.Method))
    
    // ... xử lý request ...
    
    duration := time.Since(start).Milliseconds()
    latencyHistogram.Record(ctx, float64(duration))
}
```

---

## 3️⃣ LOGS — Nhật ký sự kiện

**Logs** là bản ghi chi tiết về những gì đã xảy ra, khi nào, và context là gì.

```
Structured Log (tốt hơn):           Plain Text Log (tránh):
─────────────────────────           ────────────────────────
{                                   2024-01-15 ERROR payment failed
  "timestamp": "2024-01-15T...",    for user 123 amount 500
  "level": "ERROR",
  "service": "payment-svc",         → Khó parse, khó filter,
  "trace_id": "abc123",               không có trace_id để
  "user_id": "123",                   correlate với traces
  "amount": 500,
  "error": "bank timeout",          → Structured log cho phép
  "message": "Payment failed"         query: level=ERROR AND
}                                      service=payment-svc
```

---

## 🏗️ Kiến trúc OTel đầy đủ

```
                   YOUR APPLICATION
┌──────────────────────────────────────────────────┐
│                                                  │
│  Code của bạn                                    │
│  ┌──────────────────────────────────────────┐   │
│  │  OTel SDK (auto hoặc manual instrument)  │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ │   │
│  │  │ Traces   │ │ Metrics  │ │  Logs    │ │   │
│  │  └──────────┘ └──────────┘ └──────────┘ │   │
│  └──────────────────────────────────────────┘   │
│                        │                         │
└────────────────────────│─────────────────────────┘
                         │ OTLP Protocol
                         ▼
              ┌─────────────────────┐
              │   OTel Collector    │  ← Trung tâm xử lý
              │                     │
              │  ┌───────────────┐  │
              │  │   Receivers   │  │  ← Nhận data
              │  │   Processors  │  │  ← Filter, enrich
              │  │   Exporters   │  │  ← Gửi đi
              │  └───────────────┘  │
              └─────────────────────┘
                         │
              ┌──────────┼──────────┐
              ▼          ▼          ▼
          Jaeger    Prometheus    Loki
         (Traces)   (Metrics)    (Logs)
              └──────────┼──────────┘
                         ▼
                      Grafana
                   (Dashboard)
```

---

## ⚡ Auto-Instrumentation vs Manual

```
AUTO-INSTRUMENTATION                MANUAL INSTRUMENTATION
─────────────────────               ──────────────────────
✅ Không cần sửa code app           ✅ Kiểm soát chính xác
✅ Bắt đầu nhanh                    ✅ Custom attributes/spans
✅ Bao phủ framework tự động        ✅ Business logic metrics
❌ Ít chi tiết                      ❌ Tốn thời gian code
❌ Không có business context        ❌ Cần hiểu OTel API

# Cách dùng auto-instrumentation (Java):
java -javaagent:opentelemetry-javaagent.jar \
     -Dotel.service.name=payment-svc \
     -Dotel.exporter.otlp.endpoint=http://collector:4317 \
     -jar app.jar
```

---

## 🔗 Tài liệu tiếp theo

- **[03_prometheus.md](03_prometheus.md)** — Metrics đến Prometheus, viết PromQL
- **[04_grafana_loki.md](04_grafana_loki.md)** — Visualize traces, metrics, logs
- Nguồn gốc: [OpenTelemetry Docs](https://opentelemetry.io/docs)
