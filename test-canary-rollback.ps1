# ============================================
# TEST CANARY DEPLOYMENT - ROLLBACK SCENARIO
# ============================================
# Script này sẽ:
# 1. Update image version với ERROR_RATE=0.5 (50% lỗi)
# 2. Analysis sẽ FAIL vì success-rate < 0.95
# 3. Rollout sẽ tự động ROLLBACK về version cũ

Write-Host "===================================" -ForegroundColor Cyan
Write-Host "TEST CANARY DEPLOYMENT - ROLLBACK" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""

# Bước 1: Lấy version hiện tại
Write-Host "[1/5] Kiểm tra version hiện tại..." -ForegroundColor Yellow
$currentVersion = kubectl get rollout backend-rollout -n fullstack-namespace -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="VERSION")].value}'
Write-Host "Version hiện tại: $currentVersion" -ForegroundColor White
Write-Host ""

# Bước 2: Update version mới với ERROR_RATE=0.5 (50% requests sẽ fail)
Write-Host "[2/5] Update image version với ERROR_RATE=0.5 (50% lỗi)..." -ForegroundColor Yellow
Write-Host "⚠️  Version mới sẽ có 50% requests trả về lỗi 500!" -ForegroundColor Red
kubectl patch rollout backend-rollout -n fullstack-namespace --type=json -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/env/0/value", "value": "v3.0-buggy"},
  {"op": "replace", "path": "/spec/template/spec/containers/0/env/1/value", "value": "0.5"}
]'
Write-Host "✅ Đã trigger Canary deployment với version lỗi!" -ForegroundColor Green
Write-Host ""

# Bước 3: Đợi 5 giây
Write-Host "[3/5] Đợi rollout bắt đầu..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
Write-Host ""

# Bước 4: Theo dõi rollout
Write-Host "[4/5] Theo dõi Canary deployment (Ctrl+C để dừng)..." -ForegroundColor Yellow
Write-Host ""
Write-Host "CHÚ Ý QUAN SÁT:" -ForegroundColor Cyan
Write-Host "- Step 1-2: Deploy 20% canary pods" -ForegroundColor White
Write-Host "- Step 3: Analysis sẽ FAIL vì success-rate < 0.95 (chỉ ~50%)" -ForegroundColor Red
Write-Host "- Rollout sẽ tự động ABORT và ROLLBACK về version $currentVersion" -ForegroundColor Yellow
Write-Host ""
Write-Host "Dự kiến: Analysis fail sau ~1-2 phút" -ForegroundColor Yellow
Write-Host ""

# Hiển thị rollout status realtime
kubectl argo rollouts get rollout backend-rollout -n fullstack-namespace --watch

Write-Host ""
Write-Host "[5/5] Kiểm tra kết quả rollback..." -ForegroundColor Yellow
Write-Host ""

# Kiểm tra rollout status
$rolloutStatus = kubectl get rollout backend-rollout -n fullstack-namespace -o jsonpath='{.status.phase}'
Write-Host "Rollout Status: $rolloutStatus" -ForegroundColor $(if ($rolloutStatus -eq "Degraded") { "Red" } else { "Yellow" })

# Kiểm tra version sau rollback
Write-Host ""
Write-Host "Version sau rollback:" -ForegroundColor Cyan
$finalVersion = kubectl get rollout backend-rollout -n fullstack-namespace -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="VERSION")].value}'
Write-Host $finalVersion -ForegroundColor $(if ($finalVersion -eq $currentVersion) { "Green" } else { "Red" })
Write-Host ""

if ($finalVersion -eq $currentVersion) {
    Write-Host "✅ ROLLBACK THÀNH CÔNG! Đã quay về version $currentVersion" -ForegroundColor Green
} else {
    Write-Host "⚠️  Version không khớp. Kiểm tra lại status." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "====================================" -ForegroundColor Yellow
Write-Host "AUTO-ROLLBACK TEST HOÀN TẤT" -ForegroundColor Yellow
Write-Host "====================================" -ForegroundColor Yellow
