# ⚡ TÓM TẮT LUỒNG CHÍNH DỰ ÁN

## 🎯 LUỒNG HOÀN CHỈNH: TỪ CODE ĐẾN PRODUCTION

```
┌──────────────────────────────────────────────────────────────────────────┐
│ BƯỚC 1: DEVELOPER WORKFLOW                                               │
└──────────────────────────────────────────────────────────────────────────┘

Developer viết code
       ↓
Git commit + push to main branch
       ↓
GitHub nhận code changes (FE/src/ hoặc BE/app.py)


┌──────────────────────────────────────────────────────────────────────────┐
│ BƯỚC 2: CI PIPELINE (GitHub Actions)                                     │
└──────────────────────────────────────────────────────────────────────────┘

GitHub Actions workflow triggered (.github/workflows/cicd.yml)
       ↓
[Job: build-frontend]              [Job: build-backend]
  ├─ Checkout code                   ├─ Checkout code
  ├─ Login Docker Hub                ├─ Login Docker Hub
  ├─ Build image                     ├─ Build image
  │  docker build FE/                │  docker build BE/
  │  Tag: latest + <git-sha>         │  Tag: latest + <git-sha>
  ├─ Push to Docker Hub              ├─ Push to Docker Hub
  │  nkd7059181/frontend:xxx         │  nkd7059181/backend:xxx
  ├─ Update manifest với yq          ├─ Update manifest với yq
  │  FE/deployment.yaml               │  BE/deployment.yaml
  └─ Git commit + push manifest      └─ Git commit + push manifest


┌──────────────────────────────────────────────────────────────────────────┐
│ BƯỚC 3: GITOPS SYNC (ArgoCD)                                             │
└──────────────────────────────────────────────────────────────────────────┘

ArgoCD poll GitHub repo (mỗi 3 phút)
       ↓
Detect manifest changes
       ↓
Compare: Git (desired) vs Cluster (live)
       ↓
Status: OutOfSync
       ↓
Auto-Sync triggered
  ├─ Root App (root-app-manager) sync trước
  │  ├─ Monitors: CICD_repo/argocd/apps/
  │  └─ Tạo/Update các Child Apps
  ↓
  ├─ Child Apps sync
  │  ├─ frontend-dev → Apply FE/deployment.yaml
  │  ├─ backend-dev → Apply BE/rollout.yaml
  │  ├─ kube-prometheus-stack → Deploy monitoring
  │  ├─ argo-rollouts → Deploy rollout controller
  │  ├─ servicemonitor → Config Prometheus scraping
  │  └─ grafana-dashboard → Create dashboard
  ↓
Apply changes to Kubernetes
       ↓
Status: Synced + Healthy


┌──────────────────────────────────────────────────────────────────────────┐
│ BƯỚC 4A: FRONTEND DEPLOYMENT (Standard K8s)                              │
└──────────────────────────────────────────────────────────────────────────┘

Kubernetes Deployment Controller
       ↓
Tạo ReplicaSet
       ↓
Scale up new pods với image mới
       ↓
Rolling update (mặc định)
  ├─ maxSurge: 1 (tạo 1 pod mới trước)
  └─ maxUnavailable: 0 (không terminate pod cũ cho đến khi pod mới Ready)
       ↓
Wait for new pods Ready
       ↓
Scale down old pods
       ↓
Service route traffic đến new pods
       ↓
Deployment: Ready (2/2 replicas)


┌──────────────────────────────────────────────────────────────────────────┐
│ BƯỚC 4B: BACKEND CANARY DEPLOYMENT (Argo Rollouts)                       │
└──────────────────────────────────────────────────────────────────────────┘

Argo Rollouts Controller detect Rollout changes
       ↓
Start Canary deployment process
       ↓
┌─────────────────────────────────────────────────────────────┐
│ STEP 1: SetWeight 20%                                       │
│ ├─ Create Canary ReplicaSet                                 │
│ │  └─ Scale up 2 pods (image: backend:<new-sha>)           │
│ ├─ Keep Stable ReplicaSet                                   │
│ │  └─ 2 pods (image: backend:<old-sha>)                    │
│ └─ Update Service selectors                                 │
│    ├─ backend-svc → 80% to Stable, 20% to Canary          │
│    └─ backend-canary-svc → 100% to Canary                 │
│                                                             │
│ Total: 4 pods running (2 Stable + 2 Canary)               │
└─────────────────────────────────────────────────────────────┘
       ↓ Wait 30 seconds
┌─────────────────────────────────────────────────────────────┐
│ STEP 2: Pause 30s                                           │
│ └─ Đợi metrics được Prometheus thu thập                    │
└─────────────────────────────────────────────────────────────┘
       ↓
┌─────────────────────────────────────────────────────────────┐
│ STEP 3: Analysis (50 seconds)                               │
│ ├─ Create AnalysisRun resource                             │
│ ├─ Run 3 metrics × 5 times (interval: 10s)                 │
│ │  ├─ success-rate ≥ 0.95                                  │
│ │  │  Query Prometheus: HTTP 2xx/3xx rate                  │
│ │  │  Current: 0.98 → PASS ✓                              │
│ │  ├─ latency-p95 < 1.0s                                   │
│ │  │  Query Prometheus: P95 response time                  │
│ │  │  Current: 0.15s → PASS ✓                             │
│ │  └─ pod-ready ≥ 1                                        │
│ │     Query Prometheus: Ready pod count                    │
│ │     Current: 2 → PASS ✓                                 │
│ └─ Analysis Result: SUCCESS (all 3 metrics passed)         │
└─────────────────────────────────────────────────────────────┘
       ↓ If PASS
┌─────────────────────────────────────────────────────────────┐
│ STEP 4: SetWeight 50%                                       │
│ └─ Update Service: 50% to Stable, 50% to Canary           │
└─────────────────────────────────────────────────────────────┘
       ↓ Wait 30s
┌─────────────────────────────────────────────────────────────┐
│ STEP 5: Pause 30s                                           │
└─────────────────────────────────────────────────────────────┘
       ↓
┌─────────────────────────────────────────────────────────────┐
│ STEP 6: Analysis #2 (50 seconds)                            │
│ └─ Run same 3 metrics again → PASS ✓                       │
└─────────────────────────────────────────────────────────────┘
       ↓ If PASS
┌─────────────────────────────────────────────────────────────┐
│ STEP 7: SetWeight 100%                                      │
│ ├─ Update Service: 100% to Canary (now Stable)            │
│ ├─ Scale down old Stable ReplicaSet to 0                   │
│ ├─ Promote Canary ReplicaSet to Stable                     │
│ └─ Delete old ReplicaSet                                    │
│                                                             │
│ Final: 2 pods running (all new version)                    │
└─────────────────────────────────────────────────────────────┘
       ↓
Rollout Status: Healthy ✓
Deployment complete!


┌──────────────────────────────────────────────────────────────────────────┐
│ BƯỚC 5: MONITORING & OBSERVABILITY                                       │
└──────────────────────────────────────────────────────────────────────────┘

Prometheus (monitoring namespace)
  ├─ ServiceMonitor scrapes Backend pods
  │  ├─ Endpoint: http://<pod-ip>:8080/metrics
  │  ├─ Interval: 15 seconds
  │  └─ Metrics: flask_http_request_total, flask_http_request_duration_seconds
  ↓
  ├─ Store time-series data
  └─ Used by AnalysisRun for Canary analysis

Grafana (monitoring namespace)
  ├─ Query Prometheus data
  ├─ Display "Backend Application Monitoring" dashboard
  │  ├─ HTTP Request Rate
  │  ├─ Error Rate (%)
  │  ├─ Response Time (P50, P95)
  │  ├─ Memory Usage
  │  └─ Backend Pod Status
  └─ Visualize deployment progress


┌──────────────────────────────────────────────────────────────────────────┐
│ BƯỚC 6: AUTO-ROLLBACK (NẾU CÓ LỖI)                                      │
└──────────────────────────────────────────────────────────────────────────┘

Nếu Analysis FAIL (ví dụ: success-rate < 0.95)
       ↓
┌─────────────────────────────────────────────────────────────┐
│ Analysis FAILED (failureLimit: 3)                           │
│ ├─ Measurement 1: success-rate = 0.52 → FAIL              │
│ ├─ Measurement 2: success-rate = 0.48 → FAIL              │
│ ├─ Measurement 3: success-rate = 0.51 → FAIL              │
│ └─ Total failures: 3 → Abort rollout!                      │
└─────────────────────────────────────────────────────────────┘
       ↓
Argo Rollouts Controller triggers Auto-Rollback
  ├─ Rollout Status: Degraded
  ├─ Scale down Canary ReplicaSet
  ├─ Keep Stable ReplicaSet running
  └─ Update Service: 100% to Stable
       ↓
Rollback complete: All traffic back to old version
Final status: Healthy (old version restored)


═══════════════════════════════════════════════════════════════════════════
                        TỔNG KẾT LUỒNG DỰ ÁN
═══════════════════════════════════════════════════════════════════════════

1. Developer push code → GitHub
2. GitHub Actions build Docker image → Push Docker Hub
3. GitHub Actions update K8s manifest → Push Git
4. ArgoCD detect changes → Auto-sync to cluster
5. Frontend: Rolling update (standard)
6. Backend: Canary deployment với 6 steps
   - Step 1-3: 20% traffic → Analysis
   - Step 4-6: 50% traffic → Analysis
   - Step 7: 100% traffic (hoặc rollback nếu fail)
7. Prometheus monitor metrics realtime
8. Grafana visualize application health
9. Auto-rollback nếu metrics không đạt

THỜI GIAN DEPLOYMENT:
- Frontend: ~30-60 giây (rolling update)
- Backend: ~3-4 phút (canary với analysis)
- Rollback: ~30 giây (nếu cần)

═══════════════════════════════════════════════════════════════════════════
```

---

## 📋 NAMESPACE VÀ RESOURCES

### Namespace: `argocd`
```
Resources:
- ArgoCD Server (UI + API)
- Application Controller
- Repo Server
- Root Application (root-app-manager)
- 6 Child Applications (frontend-dev, backend-dev, ...)
```

### Namespace: `monitoring`
```
Resources:
- Prometheus Server (metrics storage)
- Grafana (visualization)
- Alertmanager (alerting)
- ServiceMonitors (scrape configs)
```

### Namespace: `argo-rollouts`
```
Resources:
- Rollouts Controller (manages Rollout resources)
- Rollouts Dashboard (UI)
```

### Namespace: `fullstack-namespace`
```
Resources:
FRONTEND:
- Deployment: frontend-deploy (2 replicas)
- Service: frontend-svc (ClusterIP)
- ConfigMap: react-nginx-config

BACKEND:
- Rollout: backend-rollout (2 replicas)
- ReplicaSet: Stable + Canary (during deployment)
- Service: backend-svc (stable traffic)
- Service: backend-canary-svc (canary traffic)
- AnalysisTemplate: backend-success-rate
- AnalysisRun: (runtime, created during analysis)

MONITORING:
- ServiceMonitor: backend-monitor
- ConfigMap: grafana-backend-dashboard
```

---

## 🔑 CÁC ĐIỂM QUAN TRỌNG

### 1. **GitOps Principles**
- ✅ Git là single source of truth
- ✅ Không deploy trực tiếp vào cluster
- ✅ Mọi thay đổi phải qua Git commit
- ✅ ArgoCD tự động sync Git → Cluster

### 2. **Canary Deployment Strategy**
- ✅ Progressive traffic shifting (20% → 50% → 100%)
- ✅ Automated analysis với Prometheus metrics
- ✅ Auto-rollback khi metrics fail
- ✅ Zero-downtime deployment

### 3. **Monitoring & Observability**
- ✅ Prometheus scrape metrics mỗi 15s
- ✅ Grafana dashboard realtime visualization
- ✅ Metrics-driven deployment decisions
- ✅ Analysis runs during Canary steps

### 4. **Automation**
- ✅ CI: GitHub Actions build + push image
- ✅ CD: ArgoCD sync manifests to cluster
- ✅ Progressive Delivery: Argo Rollouts manage traffic
- ✅ Monitoring: Prometheus auto-discover targets

---

## 📊 TIMELINE DỰ ÁN

```
T+0min:    Developer push code
T+1min:    GitHub Actions build image
T+2min:    Docker image pushed to Docker Hub
T+3min:    Manifest updated and pushed to Git
T+6min:    ArgoCD detect changes (poll interval: 3 min)
T+7min:    ArgoCD sync to cluster
T+8min:    Backend Canary deployment starts
           ├─ Step 1: 20% traffic
T+8.5min:  └─ Pause 30s
T+9min:    Analysis #1 running (50s)
T+10min:   Analysis #1 PASS → Step 4: 50% traffic
T+10.5min: Pause 30s
T+11min:   Analysis #2 running (50s)
T+12min:   Analysis #2 PASS → Step 7: 100% traffic
T+12.5min: Deployment complete! ✓

TOTAL: ~12-13 phút từ code push đến production
```

---

## 🎯 KẾT LUẬN

Dự án này triển khai một **GitOps-based CI/CD pipeline** hoàn chỉnh với:

1. **Continuous Integration**: GitHub Actions tự động build và push Docker images
2. **Continuous Deployment**: ArgoCD tự động sync Git → Kubernetes
3. **Progressive Delivery**: Argo Rollouts thực hiện Canary deployment an toàn
4. **Observability**: Prometheus + Grafana monitor application health
5. **Automation**: Tất cả quy trình hoàn toàn tự động, từ code → production

**Lợi ích**:
- ✅ An toàn: Phát hiện lỗi sớm với Canary + Analysis
- ✅ Tự động: Giảm thiểu manual intervention
- ✅ Có thể audit: Mọi thay đổi đều track qua Git history
- ✅ Rollback nhanh: Tự động hoặc thủ công trong vài giây
- ✅ Zero downtime: Luôn có pods healthy phục vụ traffic
