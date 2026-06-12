# 🚀 Quick Start: Test Argo Rollouts (Step-by-Step)

## Bước 1: Chuẩn Bị (5 phút)

### 1.1. Mở 3 Terminal Windows

**Terminal 1: Main Test**
- Chạy test script
- Theo dõi progress

**Terminal 2: Grafana Dashboard**
- Xem real-time metrics
- Monitor error rate, latency

**Terminal 3: Argo Rollouts Watch**
- Watch rollout status live
- Xem analysis results

### 1.2. Start Grafana (Terminal 2)

```powershell
# Terminal 2
cd d:\Cloud_AWS\cloud-devops
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

**Mở browser**: http://localhost:3000
- Username: `admin`
- Password: (lấy từ secret - xem bên dưới)

```powershell
# Lấy Grafana password
kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

**Trong Grafana**:
1. Click **Dashboards** (left sidebar)
2. Tìm **"Backend Application Monitoring"**
3. Mở dashboard này
4. Set time range: **Last 5 minutes**
5. Enable **Auto-refresh: 5s** (top right)

---

## Bước 2: Chạy Test Successful Rollout (10 phút)

### 2.1. Apply Rollout Resources (Terminal 1)

```powershell
# Terminal 1
cd d:\Cloud_AWS\cloud-devops

# Apply resources
kubectl apply -f CICD_repo\BE\analysis-template.yaml
kubectl apply -f CICD_repo\BE\canary-service.yaml
kubectl apply -f CICD_repo\BE\rollout.yaml

# Đợi 10 giây
Start-Sleep -Seconds 10

# Check status
kubectl argo rollouts get rollout backend-rollout -n fullstack-namespace
```

**Expected output**:
```
Name:            backend-rollout
Namespace:       fullstack-namespace
Status:          ✔ Healthy
Strategy:        Canary
  Step:          8/8
  SetWeight:     100
  ActualWeight:  100
Images:          nkd7059181/backend:latest (stable)
Replicas:
  Desired:       2
  Current:       2
  Updated:       2
  Ready:         2
  Available:     2
```

### 2.2. Start Watching (Terminal 3)

```powershell
# Terminal 3
kubectl argo rollouts get rollout backend-rollout -n fullstack-namespace --watch
```

Giữ terminal này mở - nó sẽ auto-refresh!

### 2.3. Trigger Canary Deployment (Terminal 1)

```powershell
# Terminal 1
# Thay đổi VERSION để trigger rollout
kubectl set env rollout/backend-rollout -n fullstack-namespace VERSION=v2.0

Write-Host "`n🚀 Canary deployment triggered! Watch Terminal 3 for progress...`n" -ForegroundColor Green
```

### 2.4. Quan Sát Canary Flow

**Terminal 3 sẽ hiển thị**:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 1/6: SetWeight 20%
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Name:            backend-rollout
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          1/6
  SetWeight:     20
  ActualWeight:  20
Images:          
  Stable:        nkd7059181/backend:latest (v1.0)
  Canary:        nkd7059181/backend:latest (v2.0)
Replicas:
  Desired:       2
  Current:       3  # ← Có thêm 1 canary pod!
  Updated:       1  # ← Canary pod
  Ready:         3
  Available:     3
```

**Sau 30 giây**:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 2/6: Analysis Running...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Analysis:
  ✔ success-rate: 0.98 >= 0.95  ✓
  ✔ latency-p95: 0.15s < 1.0s   ✓
  ✔ pod-ready: 3 >= 1           ✓
  Status: Running
```

**Nếu analysis pass**:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 3/6: SetWeight 50%
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  SetWeight:     50
  ActualWeight:  50
```

**Cuối cùng**:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 6/6: SetWeight 100%
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Name:            backend-rollout
Status:          ✔ Healthy
Message:         Rollout completed successfully
Images:          nkd7059181/backend:latest (v2.0) ← ALL pods v2.0
Replicas:
  Desired:       2
  Current:       2
  Updated:       2
  Ready:         2
  Available:     2
```

### 2.5. Quan Sát Trong Grafana (Terminal 2 browser)

**Trong "Backend Application Monitoring" dashboard**:

**Panel "Backend HTTP Request Rate"**:
- Sẽ thấy traffic chia ra 2 lines (v1.0 và v2.0)
- Ban đầu: 80% v1.0, 20% v2.0
- Sau đó: 50% v1.0, 50% v2.0
- Cuối: 100% v2.0

**Panel "Backend Error Rate"**:
- Nên giữ ~0% trong suốt quá trình
- Nếu spike lên → analysis sẽ fail

**Panel "Backend Status"**:
- Sẽ thấy 3 pods running (2 stable + 1 canary)
- Sau khi hoàn thành: 2 pods v2.0

**Panel "Total Requests"**:
- Counter tăng liên tục

### 2.6. Timeline Expected

```
T+0s    : Trigger rollout
T+5s    : Canary pod created
T+10s   : Canary pod ready, 20% traffic routed
T+40s   : Analysis starts (running for ~30s)
T+70s   : Analysis pass → 50% traffic
T+100s  : Analysis starts again
T+130s  : Analysis pass → 100% traffic
T+140s  : Old v1.0 pods terminated
T+150s  : ✅ Rollout complete!
```

**Total time**: ~2-3 minutes

---

## Bước 3: Test Auto-Rollback (5 phút)

### 3.1. Trigger Bad Deployment

```powershell
# Terminal 1
kubectl set env rollout/backend-rollout -n fullstack-namespace VERSION=v2.0-bad ERROR_RATE=0.5

Write-Host "`n⚠️  Deploying BAD version with 50% error rate!`n" -ForegroundColor Red
Write-Host "Watch Terminal 3 for auto-rollback...`n" -ForegroundColor Yellow
```

### 3.2. Quan Sát Auto-Rollback (Terminal 3)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 1/6: SetWeight 20%
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Canary pod deployed with ERROR_RATE=50%
  20% traffic → canary
  80% traffic → stable

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 2/6: Analysis Running...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Analysis:
  ✗ success-rate: 0.60 < 0.95  ✗ FAIL (1/3)
  ✔ latency-p95: 0.15s < 1.0s  ✓
  ✔ pod-ready: 3 >= 1          ✓
  
Analysis:
  ✗ success-rate: 0.58 < 0.95  ✗ FAIL (2/3)
  
Analysis:
  ✗ success-rate: 0.62 < 0.95  ✗ FAIL (3/3)
  
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ ANALYSIS FAILED! Auto-rollback triggered...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Name:            backend-rollout
Status:          ✗ Degraded
Message:         Analysis failed: success-rate metric failed
Strategy:        Canary
  Step:          1/6  ← Stuck at step 1
  SetWeight:     0    ← Traffic reverted to 0%
  ActualWeight:  0
Images:          
  Stable:        nkd7059181/backend:latest (v2.0)  ← Good version
  Canary:        n← Bad canary terminated
Replicas:
  Desired:       2
  Current:       2  ← Back to 2 stable pods
  Updated:       0  ← No canary pods
  Ready:         2
```

### 3.3. Quan Sát Trong Grafana

**Panel "Backend Error Rate"**:
- Spike lên ~10% (20% of traffic * 50% error rate)
- Sau rollback: drop về 0%

**Panel "Backend HTTP Request Rate"**:
- Thấy v2.0-bad line xuất hiện
- Sau 30s: v2.0-bad line biến mất (pod terminated)

**Panel "Total Requests"**:
- Có một số requests fail (500 errors)

### 3.4. Timeline Expected (Bad Deployment)

```
T+0s    : Trigger bad deployment
T+5s    : Bad canary pod created
T+10s   : 20% traffic → bad canary
T+15s   : Error rate spikes in Grafana
T+40s   : Analysis starts
T+50s   : Analysis fails (1/3)
T+60s   : Analysis fails (2/3)
T+70s   : Analysis fails (3/3) → ABORT!
T+75s   : Canary pod terminated
T+80s   : All traffic back to stable v2.0
T+85s   : ✅ Rollback complete!
```

**Total time**: ~1.5 minutes

---

## Bước 4: Sử Dụng Argo Rollouts Dashboard (Optional)

### 4.1. Start Dashboard

```powershell
# Terminal mới (Terminal 4)
kubectl port-forward -n argo-rollouts svc/argo-rollouts-dashboard 3100:3100
```

**Mở browser**: http://localhost:3100

### 4.2. Features Trong Dashboard

**Visual Rollout Progress**:
- Timeline của rollout steps
- Current weight percentage
- Analysis status với icons

**ReplicaSet Status**:
- Stable RS (green)
- Canary RS (yellow/blue)
- Pods per RS

**Analysis Results**:
- Real-time metrics values
- Pass/Fail status với checkmarks
- Failure counter

**Control Buttons**:
- **Promote**: Skip remaining steps → full rollout
- **Abort**: Stop rollout → rollback
- **Restart**: Restart rollout from beginning

---

## Bước 5: Useful Commands During Test

### Check Rollout Status
```powershell
kubectl argo rollouts get rollout backend-rollout -n fullstack-namespace
```

### View Analysis Results
```powershell
kubectl get analysisrun -n fullstack-namespace
kubectl describe analysisrun <name> -n fullstack-namespace
```

### View Pods During Rollout
```powershell
kubectl get pods -n fullstack-namespace -l app=backend -w
```

### View Events
```powershell
kubectl get events -n fullstack-namespace --sort-by='.lastTimestamp'
```

### Manually Promote (skip analysis)
```powershell
kubectl argo rollouts promote backend-rollout -n fullstack-namespace
```

### Abort Rollout
```powershell
kubectl argo rollouts abort backend-rollout -n fullstack-namespace
```

### Rollback to Previous Version
```powershell
kubectl argo rollouts undo backend-rollout -n fullstack-namespace
```

---

## Bước 6: Cleanup Sau Test

```powershell
# Restore về stable state
kubectl set env rollout/backend-rollout -n fullstack-namespace VERSION=v1.0 ERROR_RATE=0

# Hoặc delete rollout và restore deployment
kubectl delete rollout backend-rollout -n fullstack-namespace
kubectl scale deployment backend-deploy -n fullstack-namespace --replicas=2
```

---

## 🎓 What To Watch For

### ✅ Success Indicators

**Terminal 3 (Rollout Watch)**:
- Status changes: `Paused` → `Running` → `Healthy`
- Analysis shows all ✓ checkmarks
- Replicas transition smoothly

**Grafana**:
- Error rate stays < 1%
- Latency stays stable
- Request rate shows gradual traffic shift

**Dashboard**:
- Green checkmarks on analysis
- Progress bar advances
- No red alerts

### ❌ Failure Indicators

**Terminal 3**:
- Status: `Degraded`
- Analysis shows ✗ crosses
- Message: "Analysis failed"

**Grafana**:
- Error rate spikes > 5%
- Latency increases significantly
- Pods showing DOWN status

**Dashboard**:
- Red X on analysis metrics
- Failure counter increments
- "Aborted" status

---

## 🐛 Troubleshooting

### Issue: Analysis Always Fails "No Data"

**Cause**: Không có traffic → Prometheus không có metrics

**Fix**:
```powershell
# Generate traffic
kubectl exec -n fullstack-namespace deployment/backend-rollout -- sh -c "for i in {1..100}; do wget -q -O- http://localhost:8080/ && sleep 0.1; done" &
```

### Issue: Rollout Stuck at "Paused"

**Fix**:
```powershell
# Check if waiting for manual promotion
kubectl argo rollouts promote backend-rollout -n fullstack-namespace
```

### Issue: Can't See Canary Pod

**Check**:
```powershell
kubectl get pods -n fullstack-namespace -l app=backend -o wide
kubectl describe rollout backend-rollout -n fullstack-namespace
```

---

## 📸 Expected Screenshots

### Terminal 3: Rollout Progress
```
Name:            backend-rollout
Namespace:       fullstack-namespace
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          1/6
  SetWeight:     20
  ActualWeight:  20
Images:          nkd7059181/backend:latest
Replicas:
  Desired:       2
  Current:       3
  Updated:       1
  Ready:         3
  Available:     3

NAME                                         KIND        STATUS        AGE  INFO
⟳ backend-rollout                            Rollout     ॥ Paused      10m  
├──# revision:2
│  └──⧉ backend-rollout-789dc6d59f           ReplicaSet  ✔ Healthy     1m   canary
│     └──□ backend-rollout-789dc6d59f-x7k2p  Pod         ✔ Running     1m   ready:1/1
└──# revision:1
   └──⧉ backend-rollout-6b6c9f4b5d           ReplicaSet  ✔ Healthy     10m  stable
      ├──□ backend-rollout-6b6c9f4b5d-abc12  Pod         ✔ Running     10m  ready:1/1
      └──□ backend-rollout-6b6c9f4b5d-def34  Pod         ✔ Running     10m  ready:1/1
```

### Grafana: Error Rate Panel
```
Time          | Error Rate
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
10:00:00      | 0.00%  ━━━━━━━━━━━━━━━━
10:00:30      | 0.00%  ━━━━━━━━━━━━━━━━
10:01:00 (Canary) | 0.50%  ━━━━ (spike during bad canary)
10:01:30 (Rollback) | 0.00%  ━━━━━━━━━━━━━━━━
10:02:00      | 0.00%  ━━━━━━━━━━━━━━━━
```

---

**Ready to test!** 🚀

Chạy lệnh này để bắt đầu:
```powershell
cd d:\Cloud_AWS\cloud-devops
.\test-argo-rollout.ps1
```
