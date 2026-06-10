# 09 — Abort Criteria & Auto-Rollback

> **Mục tiêu:** Hiểu khi nào và làm thế nào để tự động dừng canary và rollback an toàn.

---

## 🛑 Abort Criteria là gì?

Abort Criteria là **điều kiện kích hoạt việc dừng canary deploy** và quay về version cũ.

```
Canary đang chạy...
       │
       ▼
┌─────────────────────────┐     ┌─────────────────────────────┐
│ Liên tục kiểm tra:      │     │ Nếu bất kỳ điều kiện nào    │
│                         │     │ vi phạm:                     │
│ • Success rate OK?      │ ──► │                             │
│ • Latency OK?           │     │ 1. ABORT canary deploy       │
│ • Error budget OK?      │     │ 2. Scale down canary pods    │
│ • Custom metrics OK?    │     │ 3. Shift 100% → stable       │
└─────────────────────────┘     │ 4. Alert team               │
                                └─────────────────────────────┘
```

---

## 📋 Các loại Abort Condition

### 1. Analysis Failure (từ AnalysisTemplate)

```yaml
# Trong AnalysisTemplate
metrics:
- name: success-rate
  failureCondition: result[0] < 0.95  # Dưới 95% → FAIL
  failureLimit: 0                      # Không cho phép fail lần nào

# Kết quả: Nếu success rate < 95% → AnalysisRun FAILED
#          → Rollout tự động ABORT → Rollback về stable
```

### 2. Manual Abort (con người quyết định)

```bash
# Abort ngay lập tức
kubectl argo rollouts abort payment-service -n production

# Hoặc qua Dashboard: Click nút [Abort]
```

### 3. Rollout Timeout

```yaml
spec:
  progressDeadlineSeconds: 600  # 10 phút tối đa để mỗi step hoàn thành
  # Nếu quá thời gian → tự động abort
```

---

## 🔄 Rollback Flow chi tiết

```
                    ROLLBACK FLOW
                    
Trigger (Analysis Fail / Manual Abort)
                │
                ▼
    ┌───────────────────────┐
    │  Rollout → Degraded   │
    │  (hoặc Aborted)       │
    └───────────┬───────────┘
                │
                ▼
    ┌───────────────────────┐
    │  Traffic: 0% → Canary │ ← Ngay lập tức không có
    │           100% → Stable│   traffic mới đến canary
    └───────────┬───────────┘
                │
                ▼
    ┌───────────────────────┐
    │  Scale down Canary RS  │ ← Xóa dần canary pods
    │  (canary pods → 0)     │
    └───────────┬───────────┘
                │
                ▼
    ┌───────────────────────┐
    │  Alert / Notification  │ ← Slack/PagerDuty thông báo
    │  gửi đến team          │
    └───────────┬───────────┘
                │
                ▼
    ┌───────────────────────┐
    │  STABLE: v1 phục vụ   │ ← 100% traffic về version cũ
    │  100% traffic          │   System hoạt động bình thường
    └───────────────────────┘
```

---

## ⚙️ Cấu hình Abort trong Rollout

### Rollout đầy đủ với abort handling

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: payment-service
  namespace: production
spec:
  replicas: 10
  revisionHistoryLimit: 3           # Giữ 3 revision cũ để rollback
  progressDeadlineSeconds: 600      # 10 phút timeout mỗi step
  
  selector:
    matchLabels:
      app: payment-service
  
  template:
    metadata:
      labels:
        app: payment-service
    spec:
      containers:
      - name: payment-service
        image: payment-service:v2
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"

  strategy:
    canary:
      canaryService: payment-canary-svc
      stableService: payment-stable-svc
      
      trafficRouting:
        nginx:
          stableIngress: payment-ingress
      
      # Abort tự động khi analysis fail
      abortScaleDownDelaySeconds: 30    # Chờ 30s trước khi scale down canary
      
      steps:
      - setWeight: 5
      - pause: {duration: 5m}
      
      # Step analysis: phải pass mới tiếp tục
      - analysis:
          templates:
          - templateName: payment-slo-check
          args:
          - name: service-name
            value: payment-service
      
      - setWeight: 20
      - pause: {duration: 10m}
      
      - analysis:
          templates:
          - templateName: payment-slo-check
          - templateName: business-metrics-check
          args:
          - name: service-name
            value: payment-service
      
      - setWeight: 50
      - pause: {}                       # Manual approve trước khi lên 100%
      - setWeight: 100
      
      # Analysis liên tục trong background
      analysis:
        templates:
        - templateName: payment-slo-check
        args:
        - name: service-name
          value: payment-service
        startingStep: 1
```

---

## 🧪 AnalysisTemplate với Abort Criteria rõ ràng

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: payment-slo-check
  namespace: production
spec:
  args:
  - name: service-name

  metrics:

  # ─── HARD FAIL: Abort ngay nếu vi phạm ───────────────────

  - name: critical-error-rate
    interval: 30s
    count: 3                          # Kiểm tra 3 lần (90 giây)
    # Abort ngay nếu error rate vượt 5% (burn rate 50x!)
    failureCondition: result[0] > 0.05
    failureLimit: 0                   # 0 = không cho phép fail
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          sum(rate(http_requests_total{
            service="{{args.service-name}}",status=~"5.."
          }[2m]))
          /
          sum(rate(http_requests_total{
            service="{{args.service-name}}"
          }[2m]))

  # ─── SOFT FAIL: Cho phép 1 lần, lần 2 mới abort ─────────

  - name: acceptable-error-rate
    interval: 60s
    count: 5
    successCondition: result[0] <= 0.01    # Thành công nếu ≤ 1%
    failureCondition: result[0] > 0.03     # Fail nếu > 3%
    failureLimit: 1                        # Cho phép 1 lần fail
    inconclusiveLimit: 2                   # 2 lần "không chắc" thì dừng
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          sum(rate(http_requests_total{
            service="{{args.service-name}}",status=~"5.."
          }[5m]))
          /
          sum(rate(http_requests_total{
            service="{{args.service-name}}"
          }[5m]))

  # ─── LATENCY CHECK: Abort nếu chậm hơn 2x stable ────────

  - name: latency-regression
    interval: 30s
    count: 5
    successCondition: result[0] <= 0.3     # p99 ≤ 300ms
    failureCondition: result[0] > 0.6      # p99 > 600ms → fail
    failureLimit: 1
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          histogram_quantile(0.99,
            sum(rate(http_request_duration_seconds_bucket{
              service="{{args.service-name}}"
            }[5m])) by (le)
          )

  # ─── BURN RATE: Tích hợp SLO burn rate ───────────────────

  - name: burn-rate-check
    interval: 1m
    count: 5
    # Burn rate trong canary không được vượt 14.4x (ngưỡng PAGE alert)
    successCondition: result[0] < 14.4
    failureCondition: result[0] >= 14.4
    failureLimit: 0                         # 0 = không khoan nhượng
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          (
            sum(rate(http_requests_total{
              service="{{args.service-name}}",
              status=~"5.."
            }[5m]))
            /
            sum(rate(http_requests_total{
              service="{{args.service-name}}"
            }[5m]))
          ) / 0.001                         # 0.001 = 0.1% error budget (SLO 99.9%)
```

---

## 📊 Trạng thái AnalysisRun

```
AnalysisRun có 5 trạng thái:

┌──────────────┬────────────────────────────────────────────┐
│ Trạng thái   │ Nghĩa và hành động Rollout                 │
├──────────────┼────────────────────────────────────────────┤
│ Running      │ Đang kiểm tra, chưa có kết quả             │
│              │ → Rollout: Tiếp tục theo plan               │
├──────────────┼────────────────────────────────────────────┤
│ Successful   │ Tất cả metrics đạt successCondition        │
│              │ → Rollout: Tiếp tục sang step tiếp theo    │
├──────────────┼────────────────────────────────────────────┤
│ Failed       │ failureCondition bị vi phạm                │
│              │ → Rollout: ABORT → Auto rollback!          │
├──────────────┼────────────────────────────────────────────┤
│ Inconclusive │ Không đủ data để kết luận                  │
│              │ → Rollout: PAUSE (chờ human decision)      │
├──────────────┼────────────────────────────────────────────┤
│ Error        │ Lỗi kỹ thuật (Prometheus không phản hồi)  │
│              │ → Rollout: PAUSE (thường không auto-abort) │
└──────────────┴────────────────────────────────────────────┘
```

---

## 🔔 Notification khi Abort

### Cấu hình Argo Rollouts Notifications

```yaml
# notification-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argo-rollouts-notification-configmap
  namespace: argo-rollouts
data:
  # Template cho thông báo abort
  template.rollout-aborted: |
    message: |
      🔴 *Rollout ABORTED*
      Rollout: {{.rollout.metadata.name}}
      Namespace: {{.rollout.metadata.namespace}}
      Reason: {{.rollout.status.message}}
      
      ⚡ Đã tự động rollback về version stable.
      Vui lòng kiểm tra metrics và logs!
    slack:
      attachments: |
        [{
          "color": "#E53935",
          "title": "Rollout Aborted — {{.rollout.metadata.name}}",
          "fields": [
            {"title": "Namespace", "value": "{{.rollout.metadata.namespace}}", "short": true},
            {"title": "Image", "value": "{{.rollout.spec.template.spec.containers[0].image}}", "short": true}
          ]
        }]

  # Trigger: Khi nào gửi thông báo
  trigger.on-rollout-aborted: |
    - condition: rollout.status.abort == true
      send: [rollout-aborted]

---
# Khai báo destinations (Slack channel)
apiVersion: v1
kind: Secret
metadata:
  name: argo-rollouts-notification-secret
  namespace: argo-rollouts
stringData:
  slack-token: "xoxb-your-slack-token"
```

### Annotate Rollout để nhận thông báo

```yaml
# Trong Rollout metadata
metadata:
  annotations:
    notifications.argoproj.io/subscribe.on-rollout-aborted.slack: "#deployments-alerts"
    notifications.argoproj.io/subscribe.on-rollout-completed.slack: "#deployments-info"
```

---

## 🚦 Tổng hợp: Decision Tree khi Canary

```
Deploy canary v2
       │
       ▼
Analysis bắt đầu
       │
   ┌───┴────────────────────────────────────────┐
   │                                            │
   ▼ Metrics OK                                ▼ Metrics FAIL
   │                                            │
Continue canary                            Auto ABORT
   │                                            │
   ▼                                       Rollback → v1
Tăng % traffic                                  │
   │                                       Alert team
   ▼                                            │
Lặp lại                                   Investigate
   │
   ▼ 100% traffic → v2
Deploy thành công! ✅
   │
   ▼
Post-promotion analysis
   │
   ├── PASS → Done 🎉
   └── FAIL → Alert (rollback manual hoặc auto tùy config)
```

---

## 💡 Best Practices

```
1. BẮT ĐẦU CONSERVATIVE
   → Error threshold: 1% (không phải 5%)
   → Latency threshold: p99 ≤ 300ms
   → Điều chỉnh dần sau khi quen

2. LUÔN CÓ HARD FAIL
   → failureLimit: 0 cho critical metrics
   → Không cho phép "vượt qua" khi error quá cao

3. TEST ANALYSIS TEMPLATE TRƯỚC
   → Tạo AnalysisRun độc lập để test
   → kubectl apply -f analysis-run-test.yaml

4. LOG KỸ KHI ABORT XẢY RA
   → Capture analysis results
   → Link đến Grafana dashboard
   → Runbook rõ ràng

5. KHÔNG QUÁ NGHIÊM NGẶT
   → failureLimit: 0 cho mọi thứ → nhiều false positive
   → Canary sẽ abort do blip nhỏ nhất
   → Cân bằng giữa sensitivity và reliability
```

---

## 🔗 Quay lại và nguồn gốc

- **[07_argo_rollouts.md](07_argo_rollouts.md)** — Rollout CRD cơ bản
- **[08_analysis_template.md](08_analysis_template.md)** — Chi tiết AnalysisTemplate
- **[README.md](README.md)** — Tổng quan toàn bộ bộ tài liệu
- Nguồn gốc: [Argo Rollouts — Analysis](https://argoproj.github.io/argo-rollouts/features/analysis/) | [Google SRE Workbook](https://sre.google/workbook/alerting-on-slos)
