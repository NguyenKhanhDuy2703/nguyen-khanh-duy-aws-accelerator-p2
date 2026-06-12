# Phân Tích: Argo Rollouts & Kube-Prometheus-Stack

## 📋 Mục Lục
1. [Kube-Prometheus-Stack](#kube-prometheus-stack)
2. [Argo Rollouts](#argo-rollouts)
3. [Tích Hợp Giữa Hai Hệ Thống](#tích-hợp)
4. [Use Cases Thực Tế](#use-cases)

---

## 🎯 Kube-Prometheus-Stack

### Là Gì?
**Kube-Prometheus-Stack** là một **Helm chart** tổng hợp, cài đặt một bộ monitoring stack hoàn chỉnh cho Kubernetes cluster.

### Các Thành Phần Chính

```
┌─────────────────────────────────────────────────┐
│      Kube-Prometheus-Stack                      │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌──────────────┐  ┌──────────────┐            │
│  │  Prometheus  │  │   Grafana    │            │
│  │   Server     │  │  Dashboard   │            │
│  └──────┬───────┘  └──────┬───────┘            │
│         │                  │                     │
│  ┌──────▼──────────────────▼───────┐            │
│  │   Prometheus Operator           │            │
│  │  (Quản lý Prometheus CRDs)      │            │
│  └──────┬──────────────────────────┘            │
│         │                                        │
│  ┌──────▼──────────┐  ┌──────────────┐          │
│  │  Alertmanager   │  │ Node Exporter│          │
│  │  (Cảnh báo)     │  │ (Node metrics)│         │
│  └─────────────────┘  └──────────────┘          │
│                                                 │
│  ┌────────────────────────────────┐             │
│  │    Kube-State-Metrics          │             │
│  │  (K8s cluster metrics)         │             │
│  └────────────────────────────────┘             │
└─────────────────────────────────────────────────┘
```

#### 1. **Prometheus Server**
- **Vai trò**: Time-series database, scrape và lưu trữ metrics
- **Cách hoạt động**:
  ```
  Prometheus Server
    ↓ (scrape every 15s)
  ServiceMonitor (CRD) → chỉ định target nào cần scrape
    ↓
  Backend Service :8080/metrics
    ↓
  Backend Pods expose metrics
  ```
- **Cấu hình trong file của bạn**:
  ```yaml
  prometheus:
    prometheusSpec:
      serviceMonitorSelector:
        matchLabels:
          release: kube-prometheus-stack  # Chỉ scrape ServiceMonitor có label này
      serviceMonitorNamespaceSelector:
        matchNames:
          - monitoring
          - fullstack-namespace  # Chỉ watch 2 namespaces này
  ```

#### 2. **Prometheus Operator**
- **Vai trò**: Controller quản lý Prometheus instances
- **Nhiệm vụ**:
  - Watch các ServiceMonitor CRDs
  - Tự động cập nhật Prometheus config khi ServiceMonitor thay đổi
  - Quản lý lifecycle của Prometheus pods

**Flow hoạt động**:
```
1. Bạn tạo ServiceMonitor YAML → kubectl apply
2. Prometheus Operator detect ServiceMonitor mới
3. Operator update Prometheus config file
4. Prometheus reload config (không cần restart)
5. Prometheus bắt đầu scrape target mới
```

#### 3. **Grafana**
- **Vai trò**: Visualization dashboard
- **Datasource**: Tự động cấu hình kết nối với Prometheus
- **Dashboard**: Provisioning tự động từ ConfigMaps có label `grafana_dashboard: "1"`

**Cách Grafana lấy data**:
```
User mở Grafana Dashboard
  ↓
Dashboard chạy PromQL query: rate(flask_http_request_total[5m])
  ↓
Grafana gửi query đến Prometheus datasource
  ↓
Prometheus trả về time-series data
  ↓
Grafana render chart với data
```

#### 4. **Alertmanager**
- **Vai trò**: Quản lý alerts từ Prometheus
- **Chức năng**: Routing, grouping, silencing, inhibition alerts

#### 5. **Node Exporter**
- **Vai trò**: Export hardware & OS metrics từ mỗi node
- **Metrics**: CPU, memory, disk, network của nodes

#### 6. **Kube-State-Metrics**
- **Vai trò**: Export Kubernetes object metrics
- **Metrics**: Deployments, Pods, Services, ConfigMaps status

---

## 🚀 Argo Rollouts

### Là Gì?
**Argo Rollouts** là một **Kubernetes controller** cung cấp advanced deployment strategies (Blue-Green, Canary) với khả năng automated rollback.

### Vấn Đề Nó Giải Quyết

**Kubernetes Deployment tiêu chuẩn**:
```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  strategy:
    type: RollingUpdate  # Chỉ có RollingUpdate hoặc Recreate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
```

**Hạn chế**:
- ❌ Không có Canary deployment (deploy từ từ, test trước khi full rollout)
- ❌ Không có automated analysis (tự động rollback nếu có lỗi)
- ❌ Không có traffic splitting (chia traffic giữa version cũ/mới)

**Argo Rollouts giải quyết**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
spec:
  strategy:
    canary:  # Canary deployment strategy
      steps:
      - setWeight: 20    # Deploy 20% traffic đến version mới
      - pause: {duration: 2m}  # Đợi 2 phút
      - analysis:        # Chạy analysis để check metrics
          templateName: success-rate
      - setWeight: 50    # Nếu OK, tăng lên 50%
      - pause: {duration: 2m}
      - setWeight: 100   # Cuối cùng 100% traffic
```

### Các Deployment Strategies

#### 1. **Blue-Green Deployment**
```
┌─────────────────────────────────────────┐
│  Step 1: Deploy new version (Green)     │
│  ┌────────┐         ┌────────┐          │
│  │ Blue   │ ←100%─  │ Service│          │
│  │ v1.0   │         └────────┘          │
│  └────────┘                             │
│  ┌────────┐                             │
│  │ Green  │  (idle, testing)            │
│  │ v2.0   │                             │
│  └────────┘                             │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  Step 2: Switch traffic to Green        │
│  ┌────────┐                             │
│  │ Blue   │  (idle)                     │
│  │ v1.0   │                             │
│  └────────┘                             │
│  ┌────────┐         ┌────────┐          │
│  │ Green  │ ←100%─  │ Service│          │
│  │ v2.0   │         └────────┘          │
│  └────────┘                             │
└─────────────────────────────────────────┘
```

**Ưu điểm**: Instant rollback (chỉ cần switch lại)

#### 2. **Canary Deployment**
```
Step 1: 10% traffic to v2.0
┌────────┐ ←90%─  ┌────────┐
│  v1.0  │        │Service │
│  Pods  │        └────────┘
└────────┘            │
                      ├─10%→ ┌────────┐
                             │  v2.0  │
                             │  Pods  │
                             └────────┘

Step 2: Monitor metrics for 5 minutes
  → If error_rate < 1%: Continue
  → If error_rate > 1%: Auto rollback

Step 3: Gradually increase (20%, 50%, 100%)
```

**Ưu điểm**: Giảm rủi ro, phát hiện lỗi sớm

### Automated Analysis với Prometheus

**Argo Rollouts + Prometheus** = Automated rollback dựa trên metrics!

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  metrics:
  - name: success-rate
    interval: 30s
    successCondition: result >= 0.95  # Success rate >= 95%
    failureLimit: 3  # Fail nếu 3 lần liên tiếp không đạt
    provider:
      prometheus:
        address: http://kube-prometheus-stack-prometheus.monitoring:9090
        query: |
          sum(rate(flask_http_request_total{status!="500"}[2m]))
          /
          sum(rate(flask_http_request_total[2m]))
```

**Flow hoạt động**:
```
1. Argo Rollouts deploy Canary (20% traffic)
2. Đợi 2 phút
3. Query Prometheus: success_rate >= 95%?
   ├─ YES → Continue to 50%
   └─ NO  → Auto rollback to stable version
4. Lặp lại cho mỗi step
```

---

## 🔗 Tích Hợp Giữa Hai Hệ Thống

### Kiến Trúc Tổng Thể

```
┌──────────────────────────────────────────────────────────────┐
│                    ArgoCD (GitOps)                           │
│  - Sync kube-prometheus-stack.yaml                           │
│  - Sync argo-rollouts.yaml                                   │
│  - Sync backend deployment                                   │
└────────────────────┬─────────────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
┌───────▼─────────┐      ┌────────▼────────┐
│ Prometheus      │      │ Argo Rollouts   │
│ Stack           │      │ Controller      │
│                 │      │                 │
│ - Scrape metrics│◄─────┤ - Deploy Canary │
│ - Store data    │ query│ - Run Analysis  │
│ - Alert rules   │      │ - Auto rollback │
└────────┬────────┘      └────────┬────────┘
         │                        │
         │                        │
         │   ┌────────────────────▼──────────┐
         │   │  Backend Application          │
         └──►│  - Expose /metrics            │
             │  - Rolling updates with Canary│
             └───────────────────────────────┘
```

### Workflow Trong Thực Tế

**Scenario: Deploy Backend v2.0 với Canary**

```
1. Developer: git push code v2.0
   ↓
2. CI Pipeline: Build Docker image → Push to registry
   ↓
3. Update Backend deployment.yaml → image: backend:v2.0
   ↓
4. ArgoCD detect change → Sync to cluster
   ↓
5. Argo Rollouts Controller:
   - Create new ReplicaSet with v2.0
   - Route 20% traffic to v2.0
   - Keep 80% traffic on v1.0
   ↓
6. Prometheus:
   - Scrape metrics from both v1.0 and v2.0 pods
   - Store time-series data
   ↓
7. Argo Rollouts Analysis:
   - Query Prometheus every 30s
   - Check: error_rate, response_time, request_rate
   ↓
8a. If metrics OK:
    - Increase to 50% → 100%
    - Rollout complete
    ↓
8b. If metrics BAD:
    - Auto rollback to v1.0
    - Send alert to Slack/Email
    ↓
9. Grafana:
   - Visualize metrics during rollout
   - Show comparison v1.0 vs v2.0
```

---

## 💡 Use Cases Thực Tế

### Use Case 1: Zero-Downtime Deployment

**Vấn đề**: Deploy Backend mới mà không làm gián đoạn service

**Giải pháp với Argo Rollouts**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
spec:
  strategy:
    blueGreen:
      activeService: backend-svc       # Production service
      previewService: backend-preview  # Testing service
      autoPromotionEnabled: false      # Require manual approval
```

**Flow**:
1. Deploy v2.0 → tạo preview service
2. QA team test qua preview service
3. Approve → switch traffic từ v1.0 → v2.0 instantly
4. Nếu có vấn đề → rollback trong 1 giây

### Use Case 2: Automated Canary with Metrics

**Vấn đề**: Phát hiện bug trong production sớm nhất có thể

**Giải pháp**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
spec:
  strategy:
    canary:
      steps:
      - setWeight: 10  # Only 10% users see new version
      - pause: {duration: 5m}
      - analysis:
          templates:
          - templateName: error-rate-check
          - templateName: latency-check
      - setWeight: 50
      # ... continue if metrics pass
```

**Benefit**:
- Bug chỉ ảnh hưởng 10% users (thay vì 100%)
- Auto rollback trong vòng 5 phút
- Không cần manual monitoring

### Use Case 3: A/B Testing

**Vấn đề**: Test feature mới với một phần users

**Giải pháp**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
spec:
  strategy:
    canary:
      canaryService: backend-canary-svc
      stableService: backend-stable-svc
      trafficRouting:
        istio:  # Hoặc Nginx Ingress
          virtualService:
            routes:
            - primary
      steps:
      - setWeight: 30  # 30% users see new feature
      - pause: {}      # Manual pause indefinitely
```

**Use case**: 
- 70% users: Old UI
- 30% users: New UI
- Compare metrics: conversion_rate, engagement_time
- Decide: full rollout or rollback

---

## 📊 Monitoring Rollout với Prometheus

### Metrics Quan Trọng Cần Track

#### 1. **Request Success Rate**
```promql
sum(rate(flask_http_request_total{status!="5xx"}[5m]))
/
sum(rate(flask_http_request_total[5m]))
```

#### 2. **P95 Latency**
```promql
histogram_quantile(0.95, 
  rate(flask_http_request_duration_seconds_bucket[5m])
)
```

#### 3. **Error Rate by Version**
```promql
sum(rate(flask_http_request_total{status="500",version="v2.0"}[5m]))
/
sum(rate(flask_http_request_total{version="v2.0"}[5m]))
```

#### 4. **Pod Readiness**
```promql
kube_pod_status_ready{namespace="fullstack-namespace",pod=~"backend-.*"}
```

### Grafana Dashboard cho Rollout

**Panels cần có**:
1. **Deployment Status**: Show Blue/Green or Canary progress
2. **Error Rate Comparison**: v1.0 vs v2.0
3. **Latency Comparison**: Side-by-side comparison
4. **Traffic Split**: Pie chart showing traffic percentage
5. **Pod Status**: ReplicaSet status (old vs new)

---

## 🔧 Cấu Hình Trong Project Của Bạn

### File: `kube-prometheus-stack.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kube-prometheus-stack
  namespace: argocd
spec:
  source:
    repoURL: https://prometheus-community.github.io/helm-charts
    chart: kube-prometheus-stack
    targetRevision: 65.1.1
    helm:
      values: |
        prometheus:
          prometheusSpec:
            # Chỉ scrape ServiceMonitor có label này
            serviceMonitorSelector:
              matchLabels:
                release: kube-prometheus-stack
            
            # Chỉ watch 2 namespaces này
            serviceMonitorNamespaceSelector:
              matchNames:
                - monitoring
                - fullstack-namespace
  
  destination:
    namespace: monitoring  # Cài vào namespace này
  
  syncPolicy:
    automated:
      prune: true      # Xóa resources không còn trong Git
      selfHeal: true   # Tự động sync nếu cluster khác Git
```

**Ý nghĩa**:
- **serviceMonitorSelector**: Bảo mật - chỉ scrape ServiceMonitor được approve
- **serviceMonitorNamespaceSelector**: Performance - không scan tất cả namespaces
- **automated.prune**: GitOps - xóa config cũ tự động
- **automated.selfHeal**: Reliability - tự động fix nếu ai đó kubectl edit manual

### File: `argo-rollouts.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argo-rollouts
  namespace: argocd
spec:
  source:
    repoURL: https://prometheus-community.github.io/helm-charts
    chart: argo-rollouts
    targetRevision: 2.37.7
  destination:
    namespace: argo-rollouts
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Chú ý**: File này có **lỗi cấu hình**!
- `repoURL` sai → should be Argo Rollouts Helm repo
- Không có integration config với Prometheus

**Fix đề xuất**:
```yaml
spec:
  source:
    repoURL: https://argoproj.github.io/argo-helm
    chart: argo-rollouts
    helm:
      values: |
        dashboard:
          enabled: true  # Enable Rollouts dashboard
        controller:
          metrics:
            enabled: true
            serviceMonitor:
              enabled: true
              additionalLabels:
                release: kube-prometheus-stack
```

---

## 🎓 Tóm Tắt

### Kube-Prometheus-Stack
**Mục đích**: Monitoring & Observability
- **Thu thập metrics** từ applications và cluster
- **Lưu trữ time-series data** trong Prometheus
- **Visualize** qua Grafana dashboards
- **Alert** khi có vấn đề

### Argo Rollouts
**Mục đích**: Advanced Deployment Strategies
- **Canary/Blue-Green** deployments
- **Automated analysis** dựa trên metrics từ Prometheus
- **Auto rollback** nếu metrics không đạt threshold
- **Progressive delivery** - deploy từ từ, an toàn

### Tích Hợp
```
Argo Rollouts ──(deploy)──> Application
                                  │
                                  ├──(expose)──> /metrics endpoint
                                  │
Prometheus ──(scrape)──────────────┘
     │
     └──(query)──> Argo Rollouts Analysis
                        │
                        ├─ Pass → Continue rollout
                        └─ Fail → Auto rollback
```

**Lợi ích tổng hợp**:
✅ Deploy an toàn với Canary
✅ Automated rollback dựa trên real metrics
✅ Zero-downtime deployments
✅ Visibility đầy đủ qua Grafana
✅ GitOps workflow với ArgoCD

---

## 📚 Tài Nguyên Tham Khảo

- [Prometheus Operator Docs](https://prometheus-operator.dev/)
- [Argo Rollouts Documentation](https://argoproj.github.io/argo-rollouts/)
- [Kube-Prometheus-Stack Helm Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Grafana Dashboard Examples](https://grafana.com/grafana/dashboards/)

---

**Tạo bởi**: Kiro AI Assistant
**Ngày**: 2026-06-12
