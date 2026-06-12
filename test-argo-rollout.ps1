# Argo Rollouts Canary Deployment Test Script

Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     ARGO ROLLOUTS CANARY DEPLOYMENT TEST        ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Step 1: Setup
Write-Host "📋 STEP 1: SETUP ENVIRONMENT" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Gray

Write-Host "Kiểm tra Argo Rollouts controller..." -ForegroundColor White
$rolloutsRunning = kubectl get pods -n argo-rollouts -l app.kubernetes.io/name=argo-rollouts --field-selector=status.phase=Running -o name 2>$null
if ($rolloutsRunning) {
    Write-Host "✅ Argo Rollouts controller đang chạy`n" -ForegroundColor Green
} else {
    Write-Host "❌ Argo Rollouts controller không chạy!" -ForegroundColor Red
    exit 1
}

# Step 2: Backup current deployment
Write-Host "📦 STEP 2: BACKUP CURRENT DEPLOYMENT" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Gray

Write-Host "Scale down Deployment hiện tại..." -ForegroundColor White
kubectl scale deployment backend-deploy -n fullstack-namespace --replicas=0 2>&1 | Out-Null
Write-Host "✅ Deployment đã được scale down`n" -ForegroundColor Green

# Step 3: Deploy Rollout resources
Write-Host "🚀 STEP 3: DEPLOY ROLLOUT RESOURCES" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Gray

Write-Host "Applying AnalysisTemplate..." -ForegroundColor White
kubectl apply -f CICD_repo\BE\analysis-template.yaml 2>&1 | Out-Null

Write-Host "Applying Canary Service..." -ForegroundColor White
kubectl apply -f CICD_repo\BE\canary-service.yaml 2>&1 | Out-Null

Write-Host "Applying Rollout..." -ForegroundColor White
kubectl apply -f CICD_repo\BE\rollout.yaml 2>&1 | Out-Null

Write-Host "✅ Tất cả resources đã được apply`n" -ForegroundColor Green

Start-Sleep -Seconds 10

# Step 4: Check Rollout status
Write-Host "📊 STEP 4: INITIAL ROLLOUT STATUS" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Gray

kubectl argo rollouts get rollout backend-rollout -n fullstack-namespace 2>&1

Write-Host "`n✅ Initial rollout đã hoàn thành (v1.0)`n" -ForegroundColor Green

# Step 5: Trigger Canary Deployment
Write-Host "🎯 STEP 5: TRIGGER CANARY DEPLOYMENT (v2.0)" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Gray

Write-Host "Updating image to trigger rollout..." -ForegroundColor White
Write-Host "Note: Thay đổi VERSION env var để simulate version mới`n" -ForegroundColor Gray

kubectl argo rollouts set image backend-rollout -n fullstack-namespace backend-container=nkd7059181/backend:latest 2>&1 | Out-Null
kubectl set env rollout/backend-rollout -n fullstack-namespace VERSION=v2.0 2>&1 | Out-Null

Write-Host "✅ Canary deployment đã được trigger!`n" -ForegroundColor Green

# Step 6: Watch Rollout progress
Write-Host "👀 STEP 6: WATCHING CANARY ROLLOUT PROGRESS" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Gray

Write-Host "Canary deployment strategy:" -ForegroundColor White
Write-Host "  1. Deploy 20% traffic to v2.0 → pause 30s" -ForegroundColor Cyan
Write-Host "  2. Run analysis (success rate, latency, pod ready)" -ForegroundColor Cyan
Write-Host "  3. If pass → 50% traffic → pause 30s" -ForegroundColor Cyan
Write-Host "  4. Run analysis again" -ForegroundColor Cyan
Write-Host "  5. If pass → 100% traffic (full rollout)`n" -ForegroundColor Cyan

Write-Host "Watching rollout... (Ctrl+C để thoát)`n" -ForegroundColor Yellow

# Watch rollout status every 5 seconds
$iteration = 0
while ($iteration -lt 24) {  # 24 * 5s = 2 phút
    $iteration++
    
    Clear-Host
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║         CANARY ROLLOUT - LIVE STATUS            ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    Write-Host "Iteration: $iteration / 24 (watching for 2 minutes)`n" -ForegroundColor Gray
    
    kubectl argo rollouts get rollout backend-rollout -n fullstack-namespace 2>&1
    
    Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "Refreshing in 5 seconds... (Ctrl+C to exit)" -ForegroundColor Yellow
    
    Start-Sleep -Seconds 5
}

# Step 7: Final status
Write-Host "`n📈 STEP 7: FINAL STATUS" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Gray

kubectl argo rollouts status backend-rollout -n fullstack-namespace 2>&1

Write-Host "`n✅ Test hoàn tất!`n" -ForegroundColor Green

# Step 8: Useful commands
Write-Host "🔧 USEFUL COMMANDS" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Gray

Write-Host "View rollout history:" -ForegroundColor Cyan
Write-Host "  kubectl argo rollouts history backend-rollout -n fullstack-namespace`n" -ForegroundColor White

Write-Host "Rollback to previous version:" -ForegroundColor Cyan
Write-Host "  kubectl argo rollouts undo backend-rollout -n fullstack-namespace`n" -ForegroundColor White

Write-Host "Abort current rollout:" -ForegroundColor Cyan
Write-Host "  kubectl argo rollouts abort backend-rollout -n fullstack-namespace`n" -ForegroundColor White

Write-Host "Promote canary immediately (skip analysis):" -ForegroundColor Cyan
Write-Host "  kubectl argo rollouts promote backend-rollout -n fullstack-namespace`n" -ForegroundColor White

Write-Host "View rollout in dashboard:" -ForegroundColor Cyan
Write-Host "  kubectl port-forward -n argo-rollouts svc/argo-rollouts-dashboard 3100:3100" -ForegroundColor White
Write-Host "  http://localhost:3100`n" -ForegroundColor White

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host "Test completed! Check Grafana for metrics visualization." -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Gray
