# 08 — AnalysisTemplate: Tự động phân tích metrics trong Canary

> **Mục tiêu:** Hiểu AnalysisTemplate CRD, cách tích hợp với Prometheus, và kết hợp vào Rollout.

---

## 🔍 AnalysisTemplate là gì?

**AnalysisTemplate** là một Kubernetes CRD của Argo Rollouts, định nghĩa:
- **Query** metrics từ đâu (Prometheus, Datadog, ...)
- **Điều kiện** thành công / thất bại
- **Tần suất** kiểm tra và thời gian chờ

```
Rollout biết "deploy bao nhiêu %"
AnalysisTemplate biết "có nên tiếp tục không"

┌───────────────────────────────────────────────────────────┐
│                                                           │
│  Rollout            AnalysisTemplate         Prometheus   │
│  ─────────          ─────────────────        ──────────── │
│                                                           │
│  Step 1: 5%  ──►  Run Analysis  ──► Query metrics        │
│  (traffic)         │                      │              │
│                    │◄── success_rate OK? ──┘              │
│                    │                                      │
│  Step 2: 20% ◄── PASS: Continue                          │
│  (traffic)   ◄── FAIL: Auto-abort → Rollback             │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

---

## 📄 Cấu trúc AnalysisTemplate

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate            # CRD của Argo Rollouts
metadata:
  name: success-rate              # Tên template
  namespace: production
spec:
  # ─── ARGS: Tham số đầu vào (truyền từ Rollout) ────────────
  args:
  - name: service-name            # Tên service để filter metrics
  - name: namespace
    value: production             # Giá trị mặc định
  - name: error-rate-threshold
    value: "0.01"                 # 1% error rate tối đa

  # ─── METRICS: Định nghĩa các phép đo ──────────────────────
  metrics:
  - name: success-rate            # Tên metric
    interval: 30s                 # Query mỗi 30 giây
    count: 5                      # Chạy 5 lần (tổng 2.5 phút)
    successCondition: result[0] >= 0.99   # Phải ≥ 99%
    failureLimit: 1               # Cho phép fail tối đa 1 lần
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          sum(rate(http_requests_total{
            service="{{args.service-name}}",
            status!~"5.."
          }[5m]))
          /
          sum(rate(http_requests_total{
            service="{{args.service-name}}"
          }[5m]))
```

---

## 🏭 Các Metric Provider phổ biến

### 1. Prometheus (phổ biến nhất)

```yaml
metrics:
- name: success-rate
  provider:
    prometheus:
      address: http://prometheus-operated.monitoring:9090
      query: |
        sum(rate(http_requests_total{
          job="{{args.service-name}}",
          status!~"5.."
        }[5m]))
        /
        sum(rate(http_requests_total{
          job="{{args.service-name}}"
        }[5m]))
```

### 2. Datadog

```yaml
metrics:
- name: error-rate
  provider:
    datadog:
      apiVersion: v2
      query: |
        avg:trace.http.request.errors{service:{{args.service-name}}}
        /
        avg:trace.http.request.hits{service:{{args.service-name}}}
```

### 3. Web (HTTP endpoint custom)

```yaml
metrics:
- name: custom-business-metric
  provider:
    web:
      url: "https://metrics-api.example.com/checkout-rate?service={{args.service-name}}"
      headers:
      - key: Authorization
        value: "Bearer {{args.api-token}}"
      jsonPath: "{$.checkout_success_rate}"
```

---

## 📐 Điều kiện thành công / thất bại

```yaml
# successCondition và failureCondition sử dụng expr ngôn ngữ
# result[0] = giá trị trả về từ query

# ─── Ví dụ các điều kiện ────────────────────────────────────

# Availability ≥ 99%
successCondition: result[0] >= 0.99

# Error rate ≤ 1%
successCondition: result[0] <= 0.01

# Latency p99 ≤ 500ms (0.5 seconds)
successCondition: result[0] <= 0.5

# Phức tạp hơn: giữa 0 và 1
successCondition: result[0] >= 0.995 && result[0] <= 1.0

# ─── failureCondition (nếu có → fail ngay lập tức) ──────────
failureCondition: result[0] < 0.95  # Dưới 95% → fail ngay!

# ─── failureLimit: Cho phép fail bao nhiêu lần ────────────
failureLimit: 1   # Cho phép 1 lần fail, lần 2 → abort
failureLimit: 0   # Không cho phép bất kỳ lần fail nào

# ─── inconclusiveLimit: Kết quả không xác định ────────────
# (khi không có đủ data, query lỗi, ...)
inconclusiveLimit: 3  # 3 lần không xác định → inconclusive
```

---

## 🔌 Tích hợp AnalysisTemplate vào Rollout

### Cách 1: Background Analysis (chạy song song)

```yaml
# rollout.yaml
spec:
  strategy:
    canary:
      steps:
      - setWeight: 5
      - pause: {duration: 2m}
      - setWeight: 20
      - pause: {duration: 5m}
      
      # Analysis chạy NGAY KHI bắt đầu canary
      # và tiếp tục chạy trong suốt quá trình
      analysis:
        templates:
        - templateName: success-rate
        args:
        - name: service-name
          value: payment-service
        startingStep: 1        # Bắt đầu phân tích từ step 1
```

### Cách 2: Inline Step Analysis (analysis trong từng step)

```yaml
spec:
  strategy:
    canary:
      steps:
      - setWeight: 20
      
      # Chạy analysis TRƯỚC KHI tiếp tục step tiếp theo
      - analysis:
          templates:
          - templateName: success-rate
          args:
          - name: service-name
            value: payment-service
      
      - setWeight: 50
      - pause: {duration: 10m}
      - setWeight: 100
```

### Cách 3: Pre/Post Promotion Analysis

```yaml
spec:
  strategy:
    canary:
      steps:
      - setWeight: 50
      - pause: {duration: 30m}
      
      # Analysis TRƯỚC khi promote lên 100%
      prePromotionAnalysis:
        templates:
        - templateName: success-rate
        - templateName: latency-check
        args:
        - name: service-name
          value: payment-service
      
      # Analysis SAU KHI promote (verify stable deployment)
      postPromotionAnalysis:
        templates:
        - templateName: smoke-test
```

---

## 📋 AnalysisTemplate hoàn chỉnh với nhiều metrics

```yaml
# analysis-template-full.yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: payment-slo-check
  namespace: production
spec:
  args:
  - name: service-name
  - name: canary-hash           # Label để filter canary pods
  - name: error-threshold
    value: "0.01"
  - name: latency-threshold
    value: "0.5"

  metrics:
  
  # ─── Metric 1: Success Rate ────────────────────────────────
  - name: success-rate
    interval: 30s
    count: 10                   # 10 lần × 30s = 5 phút total
    successCondition: result[0] >= 0.99
    failureCondition: result[0] < 0.95
    failureLimit: 1
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          sum(
            rate(http_requests_total{
              service="{{args.service-name}}",
              rollouts_pod_template_hash="{{args.canary-hash}}",
              status!~"5.."
            }[5m])
          )
          /
          sum(
            rate(http_requests_total{
              service="{{args.service-name}}",
              rollouts_pod_template_hash="{{args.canary-hash}}"
            }[5m])
          )

  # ─── Metric 2: P99 Latency ─────────────────────────────────
  - name: p99-latency
    interval: 30s
    count: 10
    successCondition: result[0] <= 0.5    # ≤ 500ms
    failureCondition: result[0] > 1.0     # > 1s = fail ngay
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          histogram_quantile(0.99,
            sum(
              rate(http_request_duration_seconds_bucket{
                service="{{args.service-name}}",
                rollouts_pod_template_hash="{{args.canary-hash}}"
              }[5m])
            ) by (le)
          )

  # ─── Metric 3: Burn Rate ─────────────────────────────────
  - name: burn-rate
    interval: 1m
    count: 5
    # Burn rate < 2x là chấp nhận được trong canary
    successCondition: result[0] <= 2.0
    failureCondition: result[0] >= 14.4   # Ngưỡng page alert!
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          (
            sum(rate(http_requests_total{
              service="{{args.service-name}}",
              rollouts_pod_template_hash="{{args.canary-hash}}",
              status=~"5.."
            }[5m]))
            /
            sum(rate(http_requests_total{
              service="{{args.service-name}}",
              rollouts_pod_template_hash="{{args.canary-hash}}"
            }[5m]))
          ) / 0.001
```

---

## 🔎 Theo dõi AnalysisRun

```bash
# Xem các AnalysisRun đang chạy
kubectl get analysisrun -n production

# Chi tiết một AnalysisRun
kubectl describe analysisrun payment-service-abc123 -n production

# Kết quả output:
# Status:    Running
# Message:   
# Metrics:
#   Name:             success-rate
#   Phase:            Running
#   Successful:       8
#   Failed:           0
#   Inconclusive:     0
#   Last Update:      30s ago
#   Value:            0.9987        ← 99.87% success rate
#   
#   Name:             p99-latency
#   Phase:            Running  
#   Value:            0.245         ← 245ms p99 latency ✅
```

---

## 🔗 Tài liệu tiếp theo

- **[09_abort_criteria.md](09_abort_criteria.md)** — Khi nào abort và rollback tự động
- **[05_burn_rate_alert.md](05_burn_rate_alert.md)** — Hiểu burn rate để viết analysis đúng
- Nguồn gốc: [Argo Rollouts — Analysis Guide](https://argoproj.github.io/argo-rollouts/features/analysis/)
