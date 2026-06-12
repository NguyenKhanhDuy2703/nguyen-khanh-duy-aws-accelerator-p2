# ⚡ QUICK TEST CANARY - 5 PHÚT

## 🎯 TEST 1: DEPLOYMENT THÀNH CÔNG (3-4 phút)

```powershell
# Chạy script
.\test-canary-success.ps1

# Hoặc manual:
kubectl patch rollout backend-rollout -n fullstack-namespace --type=json -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/env/0/value", "value": "v2.0"}
]'

kubectl argo rollouts get rollout backend-rollout -n fullstack-namespace --watch
```

**Kết quả mong đợi:**
- Step 1: 20% traffic → v2.0
- Step 3: Analysis PASS ✓
- Step 4: 50% traffic → v2.0
- Step 6: Analysis PASS ✓
- Step 7: 100% traffic → v2.0
- Status: **Healthy** ✓

---

## ⚠️ TEST 2: AUTO-ROLLBACK (1-2 phút)

```powershell
# Chạy script
.\test-canary-rollback.ps1

# Hoặc manual:
kubectl patch rollout backend-rollout -n fullstack-namespace --type=json -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/env/0/value", "value": "v3.0-buggy"},
  {"op": "replace", "path": "/spec/template/spec/containers/0/env/1/value", "value": "0.5"}
]'

kubectl argo rollouts get rollout backend-rollout -n fullstack-namespace --watch
```

**Kết quả mong đợi:**
- Step 1: 20% traffic → v3.0-buggy (50% lỗi)
- Step 3: Analysis FAIL ✗ (success-rate ~50% < 95%)
- Status: **Degraded** → Auto-rollback về v2.0
- Status: **Healthy** ✓

---

## 📊 QUAN SÁT QUA UI

### Grafana Dashboard
```powershell
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```
→ http://localhost:3000 (admin / prom-operator)  
→ "Backend Application Monitoring"

### Argo Rollouts UI
```powershell
kubectl argo rollouts dashboard -n fullstack-namespace
```
→ http://localhost:3100

---

## 🔧 COMMANDS HỮU ÍCH

```powershell
# Xem rollout status
kubectl get rollout backend-rollout -n fullstack-namespace

# Xem chi tiết
kubectl describe rollout backend-rollout -n fullstack-namespace

# Xem analysis runs
kubectl get analysisrun -n fullstack-namespace

# Abort rollout
kubectl argo rollouts abort backend-rollout -n fullstack-namespace

# Rollback thủ công
kubectl argo rollouts undo backend-rollout -n fullstack-namespace

# Promote (skip analysis)
kubectl argo rollouts promote backend-rollout -n fullstack-namespace
```

---

## 📖 ĐỌC THÊM

Chi tiết đầy đủ: `HUONG-DAN-TEST-CANARY.md`
