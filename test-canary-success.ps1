# ============================================
# TEST CANARY DEPLOYMENT - SUCCESS SCENARIO
# ============================================
# Script này sẽ:
# 1. Update image version từ v1.0 → v2.0
# 2. Theo dõi quá trình Canary deployment
# 3. Hiển thị analysis results

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "TEST CANARY DEPLOYMENT - SUCCESS" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Bước 1: Lấy version hiện tại
Write-Host "[1/5] Kiểm tra version hiện tại..." -ForegroundColor Yellow
kubectl get rollout backend-rollout -n fullstack-namespace -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="VERSION")].value}'
Write-Host ""
Write-Host ""

# Bước 2: Update version mới (v2.0) với ERROR_RATE=0 (không có lỗi)
Write-Host "[2/5] Update image version từ v1.0 → v2.0 (ERROR_RATE=0)..." -ForegroundColor Yellow
kubectl patch rollout backend-rollout -n fullstack-namespace --type=json -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/env/0/value", "value": "v2.0"}
]'
Write-Host "✅ Đã trigger Canary deployment!" -ForegroundColor Green
Write-Host ""

# Bước 3: Đợi 5 giây để rollout bắt đầu
Write-Host "[3/5] Đợi rollout bắt đầu..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
Write-Host ""

# Bước 4: Theo dõi rollout status
Write-Host "[4/5] Theo dõi Canary deployment (Ctrl+C để dừng)..." -ForegroundColor Yellow
Write-Host ""
Write-Host "CHÚ Ý QUAN SÁT:" -ForegroundColor Cyan
Write-Host "- Step 1: SetWeight 20% → 20% traffic đến v2.0" -ForegroundColor White
Write-Host "- Step 2: Pause 30s → Đợi metrics" -ForegroundColor White
Write-Host "- Step 3: Analysis → Kiểm tra success-rate, latency, pod-ready (50s)" -ForegroundColor White
Write-Host "- Step 4: SetWeight 50% → Tăng lên 50% nếu pass" -ForegroundColor White
Write-Host "- Step 5: Pause 30s" -ForegroundColor White
Write-Host "- Step 6: Analysis → Kiểm tra lại (50s)" -ForegroundColor White
Write-Host "- Step 7: SetWeight 100% → Full rollout nếu pass" -ForegroundColor White
Write-Host ""
Write-Host "Tổng thời gian dự kiến: ~3-4 phút" -ForegroundColor Yellow
Write-Host ""

# Hiển thị rollout status realtime
kubectl argo rollouts get rollout backend-rollout -n fullstack-namespace --watch

Write-Host ""
Write-Host "[5/5] Kiểm tra kết quả..." -ForegroundColor Yellow
Write-Host ""

# Kiểm tra final status
$rolloutStatus = kubectl get rollout backend-rollout -n fullstack-namespace -o jsonpath='{.status.phase}'
Write-Host "Rollout Status: $rolloutStatus" -ForegroundColor $(if ($rolloutStatus -eq "Healthy") { "Green" } else { "Red" })

# Hiển thị version mới
Write-Host ""
Write-Host "Version hiện tại:" -ForegroundColor Cyan
kubectl get rollout backend-rollout -n fullstack-namespace -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="VERSION")].value}'
Write-Host ""
Write-Host ""

Write-Host "================================" -ForegroundColor Green
Write-Host "CANARY DEPLOYMENT TEST HOÀN TẤT" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
