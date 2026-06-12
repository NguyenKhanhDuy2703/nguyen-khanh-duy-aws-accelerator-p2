# 🚀 Argo Rollouts Test Guide

## Mục Tiêu
Test Canary deployment strategy với automated rollback dựa trên Prometheus metrics.

## Prerequisites

✅ Argo Rollouts controller running
✅ Prometheus monitoring Backend application  
✅ Backend ServiceMonitor configured
✅ Kubectl & Argo Rollouts plugin installed

### Kiểm Tra Prerequisites

```powershell
# 1. Check Argo Rollouts
kubectl get pods -n argo-rollouts

# 2. Check Prometheus targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# → http://localhost:9090/targets (tìm "backend-svc")

# 3. Check kubectl argo rollouts
kubectl argo rollouts version
```

**Nếu chưa có kubectl argo rollouts plugin:**
```powershell
# Windows (via PowerShell)
$url = "https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-windows-amd64"
$output = "$env:USERPROFILE\kubectl-argo-rollouts.exe"
Invoke-WebRequest -Uri $url -OutFile $output

# Add to PATH hoặc copy vào C:\Windows\System32\
```

---

## 📚 Files Structure

```
CICD_repo/BE/
├── deployment.yaml         # Original Deployment (backup)
├── rollout.yaml           # New Rollout resource
├── canary-service.yaml    # Canary Service for testing
├── analysis-template.yaml # Prometheus metrics analysis
└── service.yaml           # Stable Service

Scripts:
├── test-argo-rollout.ps1  # Test successful rollout
└── test-rollback.ps1      # Test auto-rollback
```

---

## 🎯 Test Scenarios

### Scenario 1: Successful Canary Deployment

**Mục tiêu**: Deploy version mới thành công với gradual traffic increase.

**Steps**:
```powershell
# 1. Run test script
.\test-argo-rollout.ps1

# 2. Script sẽ tự động:
#    - Scale down Deployment cũ
#    - Deploy Rollout với Canary strategy
#    - Trigger v2.0 deployment
#    - Watch rollout progress
```

**Expected Flow**:
```
Initial State: v1.0 running (2 replicas)
    ↓
Step 1: Deploy Canary v2.0 (20% traffic)
    ↓ pause 30s
Step 2: Run Analysis
    ├─ Success rate >= 95%? ✓
    ├─ P95 latency < 1s?    ✓
    └─ Pods ready?          ✓
    ↓
Step 3: Increase to 50% traffic
    ↓ pause 30s
Step 4: Run Analysis again ✓
    ↓
Step 5: Full rollout 100% v2.0
    ✅ SUCCESS
```

**Timeline**: ~2 minutes

**Watch Progress**:
```powershell
# In another terminal
kubectl argo rollouts get rollout backend-rollout -n fullstack-namespace --watch

# Or use dashboard
kubectl port-forward -n argo-rollouts svc/argo-rollouts-dashboard 3100:3100
# → http://localhost:3100
```

---

### Scenario 2: Auto-Rollback (Failed Deployment)

**Mục tiêu**: Deploy bad version → Analysis fails → Auto rollback.

**Steps**:
```powershell
# Run test script
.\test-rollback.ps1
```

**Expected Flow**:
```
Initial State: v1.0 running (2 replicas)
    ↓
Step 1: Deploy BAD Canary v2.0-bad (20% traffic)
        ERROR_RATE=50% (!)
    ↓ pause 30s
Step 2: Run Analysis
    ├─ Success rate >= 95%? ✗ (only ~50%)
    ├─ Failure count: 1
    ├─ Failure count: 2
    └─ Failure count: 3 → ABORT!
    ↓
Step 3: AUTO ROLLBACK
    └─ All traffic reverts to v1.0
    ✅ ROLLBACK COMPLETE
```

**Timeline**: ~1 minute

**Rollback Behavior**:
- Analysis fails after 3 consecutive failures (30s)
- Rollout status: `Degraded`
- All traffic automatically routes to stable v1.0
- Canary pods are terminated

---

## 📊 Monitoring During Rollout

### Grafana Dashboard

```powershell
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# → http://localhost:3000
# Dashboard: "Backend Application Monitoring"
```

**Metrics to Watch**:
- **Request Rate**: Should stay stable
- **Error Rate**: Should stay < 1% (or spike during bad rollout)
- **Latency**: P95 should stay < 1s
- **Backend Status**: Should show both stable + canary pods

### Prometheus Queries

```promql
# Success rate by version
sum(rate(flask_http_request_total{status!~"5.."}[1m])) by (pod)
/
sum(rate(flask_http_request_total[1m])) by (pod)

# Traffic split
count(kube_pod_labels{pod=~"backend-rollout-.*",label_rollouts_pod_template_hash!=""}) by (label_rollouts_pod_template_hash)
```

### Argo Rollouts Dashboard

```powershell
kubectl port-forward -n argo-rollouts svc/argo-rollouts-dashboard 3100:3100
# → http://localhost:3100
```

**Features**:
- Visual rollout progress
- ReplicaSet status
- Analysis results
- Pause/Resume/Abort buttons

---

## 🔧 Manual Control Commands

### View Rollout Status
```powershell
kubectl argo rollouts get rollout backend-rollout -n fullstack-namespace
```

### Promote Canary (skip analysis)
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

### View Rollout History
```powershell
kubectl argo rollouts history backend-rollout -n fullstack-namespace
```

### Restart Rollout
```powershell
kubectl argo rollouts restart backend-rollout -n fullstack-namespace
```

---

## 🧪 Advanced Tests

### Test 1: Manual Traffic Split
```powershell
# Set custom traffic weight
kubectl argo rollouts set image backend-rollout -n fullstack-namespace backend-container=nkd7059181/backend:latest
kubectl argo rollouts set weight 30 backend-rollout -n fullstack-namespace

# Watch metrics in Grafana
# Promote when ready
kubectl argo rollouts promote backend-rollout -n fullstack-namespace
```

### Test 2: Multiple Version Rollout
```powershell
# v1.0 → v2.0 → v3.0
kubectl set env rollout/backend-rollout VERSION=v2.0 -n fullstack-namespace
# Wait for completion
kubectl set env rollout/backend-rollout VERSION=v3.0 -n fullstack-namespace
```

### Test 3: Load Testing During Rollout
```powershell
# Generate traffic during rollout
kubectl run load-test --image=busybox --restart=Never -n fullstack-namespace -- /bin/sh -c "while true; do wget -q -O- http://backend-svc:8080/ && sleep 0.1; done"

# Trigger rollout
kubectl set env rollout/backend-rollout VERSION=v2.0 -n fullstack-namespace

# Watch metrics spike in Grafana

# Cleanup
kubectl delete pod load-test -n fullstack-namespace
```

---

## 🐛 Troubleshooting

### Issue: Analysis Always Fails
**Cause**: Không có traffic → metrics không đủ data

**Solution**:
```powershell
# Generate some traffic
kubectl exec -n fullstack-namespace deployment/backend-rollout -- sh -c "for i in {1..50}; do wget -q -O- http://localhost:8080/; done"
```

### Issue: Rollout Stuck in Paused State
**Solution**:
```powershell
# Resume manually
kubectl argo rollouts promote backend-rollout -n fullstack-namespace
```

### Issue: Prometheus Metrics Not Found
**Check**:
```powershell
# 1. ServiceMonitor exists
kubectl get servicemonitor -n fullstack-namespace backend-monitor

# 2. Prometheus targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# → Check http://localhost:9090/targets

# 3. Query metrics directly
kubectl exec -n fullstack-namespace deployment/backend-rollout -- wget -qO- http://localhost:8080/metrics
```

---

## 🎓 Understanding the Analysis

### AnalysisTemplate Breakdown

```yaml
metrics:
- name: success-rate
  successCondition: result >= 0.95  # Must be >= 95%
  failureLimit: 3                   # Fail after 3 consecutive failures
  interval: 10s                     # Check every 10 seconds
  provider:
    prometheus:
      query: |
        sum(rate(flask_http_request_total{status!~"5.."}[1m]))
        /
        sum(rate(flask_http_request_total[1m]))
```

**How It Works**:
1. Every 10s, query Prometheus
2. Calculate success rate from last 1 minute
3. If result >= 0.95 → PASS
4. If result < 0.95 → increment failure counter
5. If failure counter reaches 3 → ABORT rollout

**Failure Scenarios**:
- HTTP 500 errors spike → Success rate drops
- P95 latency > 1s → Analysis fails
- Pods not ready → Analysis fails

---

## 📈 Metrics Explained

### Success Rate
```promql
(Requests with status 2xx, 3xx, 4xx) / (Total requests)
```
- **Target**: >= 95%
- **Bad**: < 95% (too many 5xx errors)

### P95 Latency
```promql
95th percentile of request duration
```
- **Target**: < 1 second
- **Bad**: > 1 second (performance degradation)

### Pod Ready
```promql
Number of pods in Ready state
```
- **Target**: >= 1
- **Bad**: 0 (all pods failing)

---

## 🚀 Next Steps

After successful testing:

1. **Integrate with CI/CD**:
   - Update GitHub Actions to use Rollout instead of Deployment
   - Add automated rollout trigger on new image push

2. **Customize Analysis**:
   - Add more metrics (CPU, memory, custom business metrics)
   - Adjust thresholds based on your SLOs

3. **Production Rollout**:
   - Longer pause durations (5-10 minutes)
   - More granular traffic splits (10% → 25% → 50% → 100%)
   - Additional analysis templates

4. **Monitoring Alerts**:
   - Set up Alertmanager rules for rollout failures
   - Slack/Email notifications on auto-rollback

---

## 📚 Resources

- [Argo Rollouts Docs](https://argoproj.github.io/argo-rollouts/)
- [Canary Strategy Guide](https://argoproj.github.io/argo-rollouts/features/canary/)
- [Analysis Templates](https://argoproj.github.io/argo-rollouts/features/analysis/)
- [Prometheus Integration](https://argoproj.github.io/argo-rollouts/analysis/prometheus/)

---

**Created by**: Kiro AI Assistant  
**Date**: 2026-06-12
