# Test Auto-Rollback với Error Rate cao

Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "║      TEST AUTO-ROLLBACK (BAD DEPLOYMENT)        ║" -ForegroundColor Red
Write-Host "╚══════════════════════════════════════════════════╝`n" -ForegroundColor Red

Write-Host "⚠️  Test này sẽ deploy version với ERROR_RATE=50%`n" -ForegroundColor Yellow
Write-Host "Expected behavior:" -ForegroundColor Cyan
Write-Host "  1. Canary 20% deployed" -ForegroundColor White
Write-Host "  2. Analysis detects high error rate" -ForegroundColor White
Write-Host "  3. Rollout AUTOMATICALLY ABORTS" -ForegroundColor White
Write-Host "  4. Traffic reverts to stable v1.0`n" -ForegroundColor White

Read-Host "Press Enter to continue..."

# Deploy bad version
Write-Host "`n🚨 Deploying BAD version (ERROR_RATE=50%)...`n" -ForegroundColor Yellow

kubectl set env rollout/backend-rollout -n fullstack-namespace VERSION=v2.0-bad ERROR_RATE=0.5 2>&1 | Out-Null

Write-Host "✅ Bad version deployed. Watching for auto-rollback...`n" -ForegroundColor Green

# Watch for 90 seconds
$iteration = 0
while ($iteration -lt 18) {  # 18 * 5s = 90 seconds
    $iteration++
    
    Clear-Host
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║         AUTO-ROLLBACK TEST - LIVE STATUS         ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════════════╝`n" -ForegroundColor Red
    
    Write-Host "Iteration: $iteration / 18 (watching for 90 seconds)`n" -ForegroundColor Gray
    
    kubectl argo rollouts get rollout backend-rollout -n fullstack-namespace 2>&1
    
    $status = kubectl argo rollouts status backend-rollout -n fullstack-namespace --watch=false 2>&1
    
    if ($status -match "Degraded") {
        Write-Host "`n🎯 AUTO-ROLLBACK TRIGGERED!" -ForegroundColor Red
        Write-Host "Analysis detected high error rate and aborted rollout.`n" -ForegroundColor Yellow
        break
    }
    
    Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "Refreshing in 5 seconds..." -ForegroundColor Yellow
    
    Start-Sleep -Seconds 5
}

Write-Host "`n📊 FINAL STATUS:" -ForegroundColor Yellow
kubectl argo rollouts status backend-rollout -n fullstack-namespace 2>&1

Write-Host "`n✅ Auto-rollback test completed!`n" -ForegroundColor Green

Write-Host "Check Grafana dashboard to see error rate spike during canary.`n" -ForegroundColor Cyan

Write-Host "To restore to stable version:" -ForegroundColor Yellow
Write-Host "  kubectl set env rollout/backend-rollout -n fullstack-namespace VERSION=v1.0 ERROR_RATE=0`n" -ForegroundColor White
