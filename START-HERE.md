# 🚀 START HERE - Test Argo Rollouts trong 5 phút

## TL;DR - Chạy Test Ngay

```powershell
# 1. Mở Terminal, chạy:
cd d:\Cloud_AWS\cloud-devops

# 2. Áp dụng Rollout resources
kubectl apply -f CICD_repo\BE\analysis-template.yaml
kubectl apply -f CICD_repo\BE\canary-service.yaml
kubectl apply -f CICD_repo\BE\rollout.yaml

# 3. Đợi 10s để Rollout ready
Start-Sleep -Seconds 10

# 4. Mở terminal mới, watch rollout
kubectl argo rollouts get rollout backend-rollout -n fullstack-namespace --watch

# 5. Quay lại terminal đầu, trigger rollout
kubectl set env rollout/backend-rollout -n fullstack-namespace VERSION=v2.0
```

**DONE!** Bạn sẽ thấy canary deployment progress trong terminal.

---

## Quan Sát Trong 3 Windows

### Window 1: Rollout Status (QUAN TRỌNG!)

```powershell
kubectl argo rollouts get rollout backend-rollout -n fullstack-namespace --watch
```

**Bạn sẽ thấy**:
```
Step 1/6: 20% traffic → v2.0
  ↓ pause 30s
Step 2/6: Analysis running...
  ✔ success-rate: 0.98 >= 0.95
  ✔ latency-p95: 0.15s < 1.0s
  ✔ pod-ready: 3 >= 1
  ↓
Step 3/6: 50% traffic
  ↓
...
  ↓
Step 6/6: 100% traffic
Status: ✔ Healthy - COMPLETE!
```

### Window 2: Grafana (Optional nhưng hay!)

```powershell
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

Browser: http://localhost:3000
- Dashboard: "Backend Application Monitoring"
- Xem traffic split real-time
- Error rate monitoring

### Window 3: Pods Status (Optional)

```powershell
kubectl get pods -n fullstack-namespace -l app=backend -w
```

---

## Test Auto-Rollback (Bad Version)

```powershell
# Deploy version với 50% error rate
kubectl set env rollout/backend-rollout -n fullstack-namespace VERSION=v2.0-bad ERROR_RATE=0.5
```

**Sau 30-60s, bạn sẽ thấy**:
```
Analysis:
  ✗ success-rate: 0.60 < 0.95 FAIL (1/3)
  ✗ success-rate: 0.58 < 0.95 FAIL (2/3)
  ✗ success-rate: 0.62 < 0.95 FAIL (3/3)

Status: ✗ Degraded
Message: Analysis failed - AUTO ROLLBACK!

→ Traffic reverts to stable v2.0
→ Bad canary pod terminated
```

---

## Restore Sau Test

```powershell
# Về version stable
kubectl set env rollout/backend-rollout -n fullstack-namespace VERSION=v1.0 ERROR_RATE=0
```

---

## Commands Hữu Ích

```powershell
# Check status
kubectl argo rollouts get rollout backend-rollout -n fullstack-namespace

# Promote immediately (skip analysis)
kubectl argo rollouts promote backend-rollout -n fullstack-namespace

# Abort rollout
kubectl argo rollouts abort backend-rollout -n fullstack-namespace

# Rollback
kubectl argo rollouts undo backend-rollout -n fullstack-namespace

# History
kubectl argo rollouts history backend-rollout -n fullstack-namespace

# Dashboard
kubectl port-forward -n argo-rollouts svc/argo-rollouts-dashboard 3100:3100
# → http://localhost:3100
```

---

## Troubleshooting Quick Fix

### Analysis luôn fail "No data"

```powershell
# Generate traffic
kubectl run curl-test --image=curlimages/curl -i --rm --restart=Never -- sh -c "while true; do curl http://backend-svc.fullstack-namespace:8080/; sleep 1; done" &
```

### Rollout stuck

```powershell
kubectl argo rollouts promote backend-rollout -n fullstack-namespace
```

---

## Đọc Chi Tiết Hơn

- **QUICK-START-TEST.md** - Step-by-step guide với screenshots
- **ARGO-ROLLOUT-TEST-GUIDE.md** - Full documentation

---

**Enjoy Canary Deployments!** 🚀
