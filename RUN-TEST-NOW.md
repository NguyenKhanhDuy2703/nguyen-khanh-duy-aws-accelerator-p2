# 🚀 CHẠY TEST NGAY - 3 BƯỚC

## ✅ Plugin đã cài xong!

Bạn đã có `kubectl argo rollouts` plugin. Bây giờ test thôi!

---

## TERMINAL 1: Apply & Trigger

```powershell
cd d:\Cloud_AWS\cloud-devops

# 1. Apply resources
kubectl apply -f CICD_repo\BE\analysis-template.yaml
kubectl apply -f CICD_repo\BE\canary-service.yaml
kubectl apply -f CICD_repo\BE\rollout.yaml

# 2. Đợi 10 giây
Start-Sleep -Seconds 10

# 3. Check initial status
kubectl argo rollouts get rollout backend-rollout -n fullstack-namespace
```

**Expected output**:
```
Name:            backend-rollout
Status:          ✔ Healthy
Strategy:        Canary
Replicas:        2/2
```

---

## TERMINAL 2: Watch Rollout (MỞ TERMINAL MỚI!)

```powershell
# Chạy command này trong terminal mới
kubectl argo rollouts get rollout backend-rollout -n fullstack-namespace --watch
```

**Giữ terminal này mở!** Nó sẽ auto-update khi rollout diễn ra.

---

## QUAY LẠI TERMINAL 1: Trigger Rollout

```powershell
# Trigger canary deployment
kubectl set env rollout/backend-rollout VERSION=v2.0 -n fullstack-namespace
```

**✅ DONE!** Bây giờ xem Terminal 2 để theo dõi progress!

---

## 👀 Bạn Sẽ Thấy Trong Terminal 2:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
T+10s: Step 1/6 - 20% Canary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Name:            backend-rollout
Status:          ॥ Paused
Step:            1/6
SetWeight:       20
ActualWeight:    20

Replicas:
  Stable:  2 (v1.0)
  Canary:  1 (v2.0)  ← NEW POD!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
T+40s: Analysis Running...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Analysis:
  ✔ success-rate: 0.98 >= 0.95
  ✔ latency-p95: 0.15s < 1.0s
  ✔ pod-ready: 3 >= 1

Status: Running → Successful

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
T+70s: Step 3/6 - 50% Canary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SetWeight:       50
ActualWeight:    50

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
T+130s: Step 6/6 - 100% Rollout
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Status: ✔ Healthy
Message: Rollout completed successfully

Replicas:
  Current:  2 (all v2.0)
  
✅ COMPLETE!
```

---

## 📊 Optional: Xem Trong Grafana

**Terminal 3** (optional):
```powershell
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

Browser: http://localhost:3000
- Dashboard: "Backend Application Monitoring"
- Xem traffic split real-time
- Monitor error rate

---

## ⏱️ Timeline Dự Kiến

```
0s    : Trigger rollout
10s   : Canary pod created, 20% traffic
40s   : Analysis pass ✔
70s   : 50% traffic
100s  : Analysis pass ✔
130s  : 100% traffic
150s  : ✅ Complete!
```

**Total: 2-3 phút**

---

## 🔧 Commands Hữu Ích

```powershell
# Check status bất kỳ lúc nào
kubectl argo rollouts get rollout backend-rollout -n fullstack-namespace

# Promote ngay (skip analysis)
kubectl argo rollouts promote backend-rollout -n fullstack-namespace

# Abort rollout
kubectl argo rollouts abort backend-rollout -n fullstack-namespace

# Rollback
kubectl argo rollouts undo backend-rollout -n fullstack-namespace

# Dashboard UI
kubectl port-forward -n argo-rollouts svc/argo-rollouts-dashboard 3100:3100
# → http://localhost:3100
```

---

## 🧪 Test Auto-Rollback (Sau khi test thành công)

```powershell
# Deploy bad version với 50% error rate
kubectl set env rollout/backend-rollout VERSION=v2.0-bad ERROR_RATE=0.5 -n fullstack-namespace
```

**Sau 30-60s**:
```
Analysis:
  ✗ success-rate: 0.60 < 0.95 FAIL
  ✗ FAIL
  ✗ FAIL (3/3)
  
Status: ✗ Degraded
→ AUTO ROLLBACK! ←
```

---

## 🐛 Troubleshooting

### Analysis fails "No data"

```powershell
# Generate traffic
kubectl exec -n fullstack-namespace deployment/backend-rollout -- sh -c "for i in {1..50}; do wget -q -O- http://localhost:8080/; done"
```

### Rollout stuck

```powershell
kubectl argo rollouts promote backend-rollout -n fullstack-namespace
```

---

## 🎓 Sau Khi Test Xong

```powershell
# Restore về stable
kubectl set env rollout/backend-rollout VERSION=v1.0 ERROR_RATE=0 -n fullstack-namespace

# Hoặc cleanup
kubectl delete rollout backend-rollout -n fullstack-namespace
kubectl scale deployment backend-deploy --replicas=2 -n fullstack-namespace
```

---

**SẴN SÀNG!** Copy paste commands và chạy! 🚀
