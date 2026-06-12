# 🧪 HƯỚNG DẪN TEST CANARY DEPLOYMENT

## 📚 MỤC LỤC
1. [Tổng quan Canary Deployment](#tổng-quan)
2. [Chiến lược Canary hiện tại](#chiến-lược)
3. [Test Case 1: Deployment thành công](#test-case-1-success)
4. [Test Case 2: Auto-rollback](#test-case-2-rollback)
5. [Giám sát qua Dashboard](#giám-sát)
6. [Troubleshooting](#troubleshooting)

---

## 🎯 TỔNG QUAN CANARY DEPLOYMENT {#tổng-quan}

### Canary Deployment là gì?

Canary Deployment là chiến lược deploy **từng bước**, phân chia traffic giữa version cũ (Stable) và version mới (Canary):

```
Version cũ (Stable)     Version mới (Canary)
      80%                       20%        ← Step 1: Deploy 20%
       ↓                         ↓
   [Pod v1.0]              [Pod v2.0]
       ↓                         ↓
      50%                       50%        ← Step 2: Tăng lên 50%
       ↓                         ↓
   [Pod v1.0]              [Pod v2.0]
       ↓                         ↓
       0%                      100%        ← Step 3: Full rollout
       ↓                         ↓
                            [Pod v2.0]
```

### Tại sao dùng Canary?

✅ **An toàn**: Phát hiện lỗi sớm với traffic nhỏ (20%)  
✅ **Tự động**: Analysis metrics để quyết định tiếp tục/rollback  
✅ **Không downtime**: Luôn có pods healthy phục vụ traffic  
✅ **Giảm rủi ro**: Rollback nhanh nếu có vấn đề

---

## 🔄 CHIẾN LƯỢC CANARY HIỆN TẠI {#chiến-lược}

File cấu hình: `CICD_repo/BE/rollout.yaml`

### 6 Bước Deployment:

| Bước | Hành động | Thời gian | Mô tả |
|------|-----------|-----------|-------|
| **1** | `setWeight: 20%` | Tức thì | Deploy Canary pods, route 20% traffic đến v2.0 |
| **2** | `pause: 30s` | 30 giây | Đợi metrics được Prometheus thu thập |
| **3** | `analysis` | 50 giây | Chạy 3 metrics × 5 lần (success-rate, latency-p95, pod-ready) |
| **4** | `setWeight: 50%` | Tức thì | Nếu analysis PASS → Tăng lên 50% traffic |
| **5** | `pause: 30s` | 30 giây | Đợi metrics mới |
| **6** | `analysis` | 50 giây | Chạy analysis lần 2 |
| **7** | `setWeight: 100%` | Tức thì | Nếu analysis PASS → Full rollout 100% |

**Tổng thời gian**: ~3-4 phút (nếu thành công)

### 3 Metrics được phân tích:

**File**: `CICD_repo/BE/analysis-template.yaml`

1. **success-rate**: Tỷ lệ request thành công ≥ 95%
   ```
   successCondition: result >= 0.95
   failureLimit: 3  ← Nếu fail 3 lần → ROLLBACK
   ```

2. **latency-p95**: P95 latency < 1 giây
   ```
   successCondition: result < 1.0
   failureLimit: 3
   ```

3. **pod-ready**: Pods phải ở trạng thái Ready
   ```
   successCondition: result >= 1
   failureLimit: 3
   ```

**Cơ chế**: Mỗi metric chạy 5 lần, mỗi 10 giây (`count: 5`, `interval: 10s`)

---

## ✅ TEST CASE 1: DEPLOYMENT THÀNH CÔNG {#test-case-1-success}

### Scenario:
Deploy version mới (v2.0) **KHÔNG có lỗi** → Analysis PASS → Full rollout

### Bước 1: Chạy script tự động

```powershell
.\test-canary-success.ps1
```

**Hoặc chạy thủ công:**

```powershell
# 1. Update version từ v1.0 → v2.0
kubectl patch rollout backend-rollout -n fullstack-namespace --type=json -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/env/0/value", "value": "v2.0"}
]'

# 2. Theo dõi realtime
kubectl argo rollouts get rollout backend-rollout -n fullstack-namespace --watch
```

### Bước 2: Quan sát quá trình

Terminal sẽ hiển thị:

```
Name:            backend-rollout
Namespace:       fullstack-namespace
Status:          ॥ Progressing
Strategy:        Canary
  Step:          1/7
  SetWeight:     20
  ActualWeight:  20
Images:          nkd7059181/backend:latest (stable)
                 nkd7059181/backend:latest (canary)

NAME                                  KIND         STATUS     AGE
⟳ backend-rollout                    Rollout      ॥ Progressing 10m
├──# revision:2
│  └──⧉ backend-rollout-789abc123    ReplicaSet   ✔ Healthy   30s  ← Canary (v2.0)
│     ├──□ backend-rollout-789-aaa   Pod          ✔ Running   30s
│     └──□ backend-rollout-789-bbb   Pod          ✔ Running   30s
└──# revision:1
   └──⧉ backend-rollout-6f6c78667    ReplicaSet   ✔ Healthy   10m  ← Stable (v1.0)
      ├──□ backend-rollout-6f6-xxx   Pod          ✔ Running   10m
      └──□ backend-rollout-6f6-yyy   Pod          ✔ Running   10m
```

**Timeline:**

```
00:00 - Step 1/7: SetWeight 20%        ← Deploy canary pods
00:05 - Step 2/7: Pause 30s            ← Đợi metrics
00:35 - Step 3/7: Analysis Running     ← Kiểm tra 3 metrics × 5 lần
01:25 - Step 3/7: Analysis SUCCESS ✓   ← All metrics PASS
01:25 - Step 4/7: SetWeight 50%        ← Tăng traffic
01:30 - Step 5/7: Pause 30s
02:00 - Step 6/7: Analysis Running
02:50 - Step 6/7: Analysis SUCCESS ✓
02:50 - Step 7/7: SetWeight 100%       ← Full rollout
03:00 - Status: Healthy ✓              ← Hoàn tất!
```

### Bước 3: Xác nhận kết quả

```powershell
# Kiểm tra rollout status
kubectl get rollout backend-rollout -n fullstack-namespace

# Expected output:
# NAME              DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
# backend-rollout   2         2         2            2           15m
# Status: Healthy ✓

# Kiểm tra version mới
kubectl get rollout backend-rollout -n fullstack-namespace -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="VERSION")].value}'
# Expected: v2.0
```

### Bước 4: Test traffic đến version mới

```powershell
# Port-forward backend service
kubectl port-forward -n fullstack-namespace svc/backend-svc 8080:80

# Test (tab mới)
curl http://localhost:8080/

# Expected response:
# {"message": "Hello from Backend v2.0", "version": "v2.0"}
```

---

## ⚠️ TEST CASE 2: AUTO-ROLLBACK {#test-case-2-rollback}

### Scenario:
Deploy version mới (v3.0-buggy) **CÓ LỖI** (50% requests fail) → Analysis FAIL → Auto-rollback

### Bước 1: Chạy script tự động

```powershell
.\test-canary-rollback.ps1
```

**Hoặc chạy thủ công:**

```powershell
# 1. Update version với ERROR_RATE=0.5 (50% lỗi)
kubectl patch rollout backend-rollout -n fullstack-namespace --type=json -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/env/0/value", "value": "v3.0-buggy"},
  {"op": "replace", "path": "/spec/template/spec/containers/0/env/1/value", "value": "0.5"}
]'

# 2. Theo dõi
kubectl argo rollouts get rollout backend-rollout -n fullstack-namespace --watch
```

### Bước 2: Quan sát quá trình

```
00:00 - Step 1/7: SetWeight 20%        ← Deploy canary với lỗi
00:05 - Step 2/7: Pause 30s
00:35 - Step 3/7: Analysis Running     ← Kiểm tra metrics
00:45 - Step 3/7: Analysis FAILED ✗    ← success-rate = 50% < 95%
00:45 - Status: Degraded               ← Rollout ABORT
00:50 - Rollback to revision 2         ← Quay về v2.0
01:00 - Status: Healthy ✓              ← Rollback hoàn tất
```

**Tại sao fail?**

```yaml
# Analysis Template yêu cầu:
successCondition: result >= 0.95  # Success rate ≥ 95%

# Nhưng version buggy có:
ERROR_RATE: 0.5  # 50% requests fail → success-rate chỉ ~50%

# → Analysis FAIL → Auto-rollback!
```

### Bước 3: Xác nhận rollback

```powershell
# Kiểm tra status
kubectl get rollout backend-rollout -n fullstack-namespace
# Status: Degraded (sau đó tự chuyển về Healthy)

# Kiểm tra version đã rollback về v2.0
kubectl get rollout backend-rollout -n fullstack-namespace -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="VERSION")].value}'
# Expected: v2.0 (không phải v3.0-buggy)

# Kiểm tra analysis run
kubectl get analysisrun -n fullstack-namespace

# Output mẫu:
# NAME                                TYPE     STATUS   AGE
# backend-rollout-789abc-1-1          Canary   Failed   2m
```

### Bước 4: Xem chi tiết analysis failure

```powershell
kubectl describe analysisrun <analysisrun-name> -n fullstack-namespace
```

Output sẽ hiển thị:

```
Status:
  Phase: Failed
  Metric Results:
    Name: success-rate
    Phase: Failed
    Measurements:
      - Value: 0.52  ← Chỉ 52% < 95%
        Phase: Failed
      - Value: 0.48
        Phase: Failed
      - Value: 0.51
        Phase: Failed
    Message: Metric failed 3 times (failureLimit: 3)
```

---

## 📊 GIÁM SÁT QUA DASHBOARD {#giám-sát}

### Grafana Dashboard

1. **Mở Grafana**:
   ```powershell
   kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
   ```
   Truy cập: http://localhost:3000
   - Username: `admin`
   - Password: `prom-operator`

2. **Vào "Backend Application Monitoring" dashboard**

3. **Panels quan trọng khi test Canary**:

   - **HTTP Request Rate**: Thấy traffic tăng đột ngột khi deploy
   - **Error Rate (%)**: Thấy spike lên 50% khi deploy version lỗi
   - **Response Time (P95)**: Thấy latency thay đổi
   - **Backend Status**: Thấy số pods thay đổi (2 stable + 2 canary = 4 pods)

### Prometheus Targets

1. **Mở Prometheus**:
   ```powershell
   kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
   ```
   Truy cập: http://localhost:9090

2. **Vào Status → Targets**

3. **Kiểm tra `backend-svc` job có 4 targets** (khi đang Canary):
   - 2 pods stable (v1.0)
   - 2 pods canary (v2.0)

### Argo Rollouts UI (Optional)

```powershell
kubectl argo rollouts dashboard -n fullstack-namespace
```

Truy cập: http://localhost:3100

---

## 🔧 TROUBLESHOOTING {#troubleshooting}

### Vấn đề 1: "Analysis runs indefinitely"

**Nguyên nhân**: Thiếu `count` field trong metrics

**Giải pháp**: Đã fix ở `analysis-template.yaml` (added `count: 5`)

---

### Vấn đề 2: "Rollout stuck at Progressing"

**Kiểm tra**:
```powershell
kubectl describe rollout backend-rollout -n fullstack-namespace
```

**Nguyên nhân thường gặp**:
- Canary service không tồn tại
- Analysis template không tìm thấy
- Prometheus query lỗi

---

### Vấn đề 3: "Service route traffic sai"

**Kiểm tra endpoints**:
```powershell
kubectl get endpoints backend-svc -n fullstack-namespace
kubectl get endpoints backend-canary-svc -n fullstack-namespace
```

**Nguyên nhân**: Có cả Deployment VÀ Rollout cùng quản lý pods với label `app: backend`

**Giải pháp**:
```powershell
kubectl scale deployment backend-deploy --replicas=0 -n fullstack-namespace
# Hoặc xóa hẳn
kubectl delete deployment backend-deploy -n fullstack-namespace
```

---

### Vấn đề 4: "Analysis always fails"

**Debug Prometheus query**:

```powershell
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

Vào http://localhost:9090 → Graph → Thử query:

```promql
# Query 1: Success rate
sum(rate(flask_http_request_total{job="backend-svc",status!~"5.."}[1m]))
/
sum(rate(flask_http_request_total{job="backend-svc"}[1m]))

# Query 2: P95 Latency
histogram_quantile(0.95,
  sum(rate(flask_http_request_duration_seconds_bucket{job="backend-svc"}[1m])) by (le)
)

# Query 3: Pod ready
kube_pod_status_ready{namespace="fullstack-namespace",condition="true",pod=~"backend-rollout-.*"}
```

**Nếu query không trả về data**: Backend app chưa export metrics đúng

---

## 📌 TIPS & BEST PRACTICES

### 1. Luôn test với low traffic trước

Start với `setWeight: 10%` thay vì 20% cho môi trường production

### 2. Tăng `failureLimit` nếu metrics không ổn định

```yaml
failureLimit: 5  # Thay vì 3
```

### 3. Thêm step pause dài hơn để metrics ổn định

```yaml
- pause: {duration: 60s}  # Thay vì 30s
```

### 4. Test rollback thủ công

```powershell
# Abort rollout đang chạy
kubectl argo rollouts abort backend-rollout -n fullstack-namespace

# Rollback về revision trước
kubectl argo rollouts undo backend-rollout -n fullstack-namespace
```

### 5. Promote thủ công nếu muốn skip analysis

```powershell
kubectl argo rollouts promote backend-rollout -n fullstack-namespace
```

---

## 🎓 KẾT LUẬN

Canary Deployment với Argo Rollouts + Prometheus Analysis giúp:

✅ **Tự động hóa** deployment process  
✅ **Phát hiện lỗi sớm** với traffic nhỏ  
✅ **Rollback nhanh** khi có vấn đề  
✅ **Zero downtime** cho end-users  
✅ **Tích hợp monitoring** để ra quyết định dựa trên metrics thực tế

**Next steps:**
- Test với nhiều version khác nhau
- Tune analysis metrics để phù hợp với ứng dụng
- Integrate với CI/CD pipeline (GitHub Actions)
- Add notification khi rollout fail (Slack, email)

---

**Tác giả**: Kiro AI  
**Ngày tạo**: 2026-06-12  
**Version**: 1.0
