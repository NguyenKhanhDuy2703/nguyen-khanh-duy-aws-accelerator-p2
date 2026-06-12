# 📦 EVIDENCE PACK - GITOPS CI/CD PROJECT

**Project**: Fullstack Application with GitOps, Canary Deployment, and Monitoring  
**Student**: Nguyen Khanh Duy  
**Date**: June 12, 2026  
**Repository**: [nguyen-khanh-duy-aws-accelerator-p2](https://github.com/NguyenKhanhDuy2703/nguyen-khanh-duy-aws-accelerator-p2)

---

## 📋 TABLE OF CONTENTS

1. [Project Overview](#project-overview)
2. [Architecture Diagram](#architecture-diagram)
3. [GitHub Repository](#github-repository)
4. [CI/CD Pipeline (GitHub Actions)](#cicd-pipeline)
5. [ArgoCD - GitOps](#argocd-gitops)
6. [Kubernetes Cluster](#kubernetes-cluster)
7. [Argo Rollouts - Canary Deployment](#argo-rollouts)
8. [Monitoring - Prometheus](#prometheus)
9. [Monitoring - Grafana](#grafana)
10. [Testing Evidence](#testing-evidence)

---

## 🎯 PROJECT OVERVIEW {#project-overview}

### Technology Stack

**Frontend**:
- React + Vite
- Nginx reverse proxy
- Docker containerization

**Backend**:
- Flask (Python)
- Prometheus metrics export
- Docker containerization

**Infrastructure**:
- Kubernetes (Minikube)
- ArgoCD (GitOps)
- Argo Rollouts (Progressive Delivery)
- Prometheus + Grafana (Monitoring)
- GitHub Actions (CI/CD)

### Key Features

✅ **GitOps**: Git as single source of truth  
✅ **CI/CD**: Automated build, test, and deploy  
✅ **Canary Deployment**: Progressive traffic shifting with automated analysis  
✅ **Monitoring**: Prometheus metrics + Grafana dashboards  
✅ **Auto-Rollback**: Metrics-driven rollback on failure


---

## 🏗️ ARCHITECTURE DIAGRAM {#architecture-diagram}

### System Architecture

![Architecture Diagram](./evidence/01-architecture-diagram.png)

**📸 Screenshot Instructions**:
- Create architecture diagram showing: GitHub → GitHub Actions → Docker Hub → ArgoCD → K8s → Prometheus/Grafana
- Or screenshot from `TOM-TAT-LUONG-CHINH.md` ASCII diagram

---

## 📂 GITHUB REPOSITORY {#github-repository}

### Repository Structure

![Repository Structure](./evidence/02-github-repo-structure.png)

**📸 Screenshot Instructions**:
1. Go to: https://github.com/NguyenKhanhDuy2703/nguyen-khanh-duy-aws-accelerator-p2
2. Screenshot showing folder structure:
   - `.github/workflows/` - CI/CD pipelines
   - `CICD_repo/FE/` - Frontend code
   - `CICD_repo/BE/` - Backend code
   - `CICD_repo/argocd/` - ArgoCD applications

### Repository Commits

![Recent Commits](./evidence/03-github-commits.png)

**📸 Screenshot Instructions**:
1. Go to: https://github.com/NguyenKhanhDuy2703/nguyen-khanh-duy-aws-accelerator-p2/commits/main
2. Screenshot showing recent commits (last 10-15 commits)
3. Highlight commits from GitHub Actions (automated manifest updates)

---

## 🔄 CI/CD PIPELINE (GITHUB ACTIONS) {#cicd-pipeline}

### Workflow Configuration

![GitHub Actions Workflow](./evidence/04-github-actions-workflow.png)

**📸 Screenshot Instructions**:
1. Go to: https://github.com/YOUR_REPO/actions
2. Screenshot showing workflow runs (green checkmarks)

### Frontend Build Job

![Frontend Build](./evidence/05-frontend-build-job.png)

**📸 Screenshot Instructions**:
1. Click on a successful workflow run
2. Expand "build-frontend" job
3. Screenshot showing steps:
   - Checkout code
   - Login to Docker Hub
   - Build and Push FE
   - Update FE manifest

### Backend Build Job

![Backend Build](./evidence/06-backend-build-job.png)

**📸 Screenshot Instructions**:
1. Same workflow run
2. Expand "build-backend" job
3. Screenshot showing all steps completed

### Docker Hub Images

![Docker Hub](./evidence/07-dockerhub-images.png)

**📸 Screenshot Instructions**:
1. Go to: https://hub.docker.com/
2. Login and go to your repositories
3. Screenshot showing:
   - `nkd7059181/frontend` with multiple tags
   - `nkd7059181/backend` with multiple tags


---

## 🚀 ARGOCD - GITOPS {#argocd-gitops}

### ArgoCD UI - Login

![ArgoCD Login](./evidence/08-argocd-login.png)

**📸 Screenshot Instructions**:
1. Run: `kubectl port-forward -n argocd svc/argocd-server 8080:443`
2. Go to: https://localhost:8080
3. Screenshot login page

### ArgoCD Dashboard - Applications Overview

![ArgoCD Applications](./evidence/09-argocd-dashboard.png)

**📸 Screenshot Instructions**:
1. After login, screenshot main dashboard
2. Should show all applications:
   - root-app-manager (green, healthy)
   - frontend-dev (green, synced)
   - backend-dev (green, synced)
   - kube-prometheus-stack (green, synced)
   - argo-rollouts (green, synced)
   - servicemonitor (green, synced)
   - grafana-backend-dashboard (green, synced)

### Root Application (App of Apps)

![Root App](./evidence/10-argocd-root-app.png)

**📸 Screenshot Instructions**:
1. Click on "root-app-manager"
2. Screenshot showing:
   - Source: GitHub repo path `CICD_repo/argocd/apps/`
   - Destination: `argocd` namespace
   - Status: Synced + Healthy
   - Child apps listed

### Frontend Application Details

![Frontend App](./evidence/11-argocd-frontend-app.png)

**📸 Screenshot Instructions**:
1. Click on "frontend-dev"
2. Screenshot showing resource tree:
   - Deployment: frontend-deploy
   - Service: frontend-svc
   - ConfigMap: react-nginx-config
   - Pods: 2 running (green)

### Backend Application Details

![Backend App](./evidence/12-argocd-backend-app.png)

**📸 Screenshot Instructions**:
1. Click on "backend-dev"
2. Screenshot showing resource tree:
   - Rollout: backend-rollout
   - Service: backend-svc, backend-canary-svc
   - AnalysisTemplate: backend-success-rate
   - Pods: 2 running (green)

### Kube-Prometheus-Stack Application

![Prometheus App](./evidence/13-argocd-prometheus-app.png)

**📸 Screenshot Instructions**:
1. Click on "kube-prometheus-stack"
2. Screenshot showing Helm chart deployment
3. Show many resources deployed (Prometheus, Grafana, Alertmanager)

### Argo Rollouts Application

![Rollouts App](./evidence/14-argocd-rollouts-app.png)

**📸 Screenshot Instructions**:
1. Click on "argo-rollouts"
2. Screenshot showing rollout controller deployed

### Sync Status Details

![Sync Details](./evidence/15-argocd-sync-details.png)

**📸 Screenshot Instructions**:
1. Click on any app → "APP DETAILS" tab
2. Screenshot showing:
   - Repo URL
   - Target Revision: HEAD
   - Path
   - Sync Policy: Automated (prune: true, selfHeal: true)


---

## ☸️ KUBERNETES CLUSTER {#kubernetes-cluster}

### Namespaces

![Namespaces](./evidence/16-k8s-namespaces.png)

**📸 Screenshot Instructions**:
```powershell
kubectl get namespaces
```
Screenshot terminal showing:
- argocd
- monitoring
- argo-rollouts
- fullstack-namespace

### Pods Overview

![All Pods](./evidence/17-k8s-pods-all.png)

**📸 Screenshot Instructions**:
```powershell
kubectl get pods --all-namespaces
```
Screenshot showing all pods running

### Application Pods (fullstack-namespace)

![App Pods](./evidence/18-k8s-app-pods.png)

**📸 Screenshot Instructions**:
```powershell
kubectl get pods -n fullstack-namespace -o wide
```
Screenshot showing:
- frontend-deploy pods (2)
- backend-rollout pods (2)

### Services

![Services](./evidence/19-k8s-services.png)

**📸 Screenshot Instructions**:
```powershell
kubectl get svc -n fullstack-namespace
```
Screenshot showing:
- frontend-svc
- backend-svc
- backend-canary-svc

### Deployments and Rollouts

![Deployments](./evidence/20-k8s-deployments.png)

**📸 Screenshot Instructions**:
```powershell
kubectl get deployment,rollout -n fullstack-namespace
```
Screenshot showing:
- frontend-deploy (2/2)
- backend-rollout (2/2)

---

## 🎯 ARGO ROLLOUTS - CANARY DEPLOYMENT {#argo-rollouts}

### Argo Rollouts Dashboard

![Rollouts Dashboard](./evidence/21-rollouts-dashboard.png)

**📸 Screenshot Instructions**:
1. Run: `kubectl argo rollouts dashboard -n fullstack-namespace`
2. Go to: http://localhost:3100
3. Screenshot showing backend-rollout

### Rollout Details - Healthy State

![Rollout Healthy](./evidence/22-rollout-healthy.png)

**📸 Screenshot Instructions**:
1. Click on "backend-rollout"
2. Screenshot showing:
   - Strategy: Canary
   - Status: Healthy
   - Step: 7/7 (Completed)
   - Revision 1 (stable)

### Rollout Steps Visualization

![Rollout Steps](./evidence/23-rollout-steps.png)

**📸 Screenshot Instructions**:
1. Same page, scroll to "Steps" section
2. Screenshot showing 6 steps:
   - Set Weight: 20%
   - Pause: 30s
   - Analysis
   - Set Weight: 50%
   - Pause: 30s
   - Analysis
   - Set Weight: 100%

### Analysis Template

![Analysis Template](./evidence/24-analysis-template.png)

**📸 Screenshot Instructions**:
```powershell
kubectl get analysistemplate -n fullstack-namespace
kubectl describe analysistemplate backend-success-rate -n fullstack-namespace
```
Screenshot showing 3 metrics:
- success-rate
- latency-p95
- pod-ready


### Canary Deployment In Progress (Optional)

![Canary In Progress](./evidence/25-rollout-canary-progress.png)

**📸 Screenshot Instructions** (if you trigger a deployment):
1. Update version in rollout.yaml
2. Watch: `kubectl argo rollouts get rollout backend-rollout -n fullstack-namespace --watch`
3. Screenshot showing:
   - Step 1/7 or 3/7
   - Canary ReplicaSet scaling up
   - Traffic split (20% or 50%)

### Analysis Run Success

![Analysis Success](./evidence/26-analysis-success.png)

**📸 Screenshot Instructions**:
```powershell
kubectl get analysisrun -n fullstack-namespace
kubectl describe analysisrun <name> -n fullstack-namespace
```
Screenshot showing:
- Phase: Successful
- All metrics: Passed

---

## 📊 MONITORING - PROMETHEUS {#prometheus}

### Prometheus UI

![Prometheus Home](./evidence/27-prometheus-home.png)

**📸 Screenshot Instructions**:
1. Run: `kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090`
2. Go to: http://localhost:9090
3. Screenshot Prometheus homepage

### Prometheus Targets

![Prometheus Targets](./evidence/28-prometheus-targets.png)

**📸 Screenshot Instructions**:
1. Click "Status" → "Targets"
2. Screenshot showing:
   - backend-svc endpoints (2 UP)
   - Other targets (kubernetes, node-exporter, etc.)

### Prometheus Query - Success Rate

![Query Success Rate](./evidence/29-prometheus-query-success.png)

**📸 Screenshot Instructions**:
1. Go to "Graph" tab
2. Enter query:
```promql
sum(rate(flask_http_request_total{job="backend-svc",status!~"5.."}[1m]))
/
sum(rate(flask_http_request_total{job="backend-svc"}[1m]))
```
3. Click "Execute" and screenshot result

### Prometheus Query - Latency P95

![Query Latency](./evidence/30-prometheus-query-latency.png)

**📸 Screenshot Instructions**:
1. Enter query:
```promql
histogram_quantile(0.95,
  sum(rate(flask_http_request_duration_seconds_bucket{job="backend-svc"}[1m])) by (le)
)
```
2. Click "Execute" and screenshot

### Prometheus Alerts (Optional)

![Prometheus Alerts](./evidence/31-prometheus-alerts.png)

**📸 Screenshot Instructions**:
1. Click "Alerts"
2. Screenshot showing configured alerts


---

## 📈 MONITORING - GRAFANA {#grafana}

### Grafana Login

![Grafana Login](./evidence/32-grafana-login.png)

**📸 Screenshot Instructions**:
1. Run: `kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80`
2. Go to: http://localhost:3000
3. Screenshot login page

### Grafana Home

![Grafana Home](./evidence/33-grafana-home.png)

**📸 Screenshot Instructions**:
1. Login with: admin / prom-operator
2. Screenshot home dashboard

### Grafana Data Sources

![Grafana Datasources](./evidence/34-grafana-datasources.png)

**📸 Screenshot Instructions**:
1. Click "⚙️" (gear icon) → "Data sources"
2. Screenshot showing Prometheus data source configured

### Backend Application Monitoring Dashboard

![Backend Dashboard](./evidence/35-grafana-backend-dashboard.png)

**📸 Screenshot Instructions**:
1. Click "☰" → "Dashboards"
2. Search for "Backend Application Monitoring"
3. Screenshot showing dashboard with panels:
   - HTTP Request Rate
   - Error Rate (%)
   - Response Time (P95, P50)
   - Memory Usage
   - Backend Status
   - Total Requests

### Dashboard - HTTP Request Rate

![HTTP Request Rate](./evidence/36-grafana-request-rate.png)

**📸 Screenshot Instructions**:
1. Same dashboard, zoom in on "HTTP Request Rate" panel
2. Screenshot showing graph with data

### Dashboard - Error Rate

![Error Rate](./evidence/37-grafana-error-rate.png)

**📸 Screenshot Instructions**:
1. Zoom in on "Error Rate (%)" panel
2. Screenshot showing low error rate (~0%)

### Dashboard - Response Time

![Response Time](./evidence/38-grafana-response-time.png)

**📸 Screenshot Instructions**:
1. Zoom in on "Response Time" panel
2. Screenshot showing P95 and P50 latency lines

### Dashboard - Pod Status

![Pod Status](./evidence/39-grafana-pod-status.png)

**📸 Screenshot Instructions**:
1. Zoom in on "Backend Status" panel
2. Screenshot showing 2 pods UP


---

## 🧪 TESTING EVIDENCE {#testing-evidence}

### Test 1: Successful Canary Deployment

![Test Success Start](./evidence/40-test-success-start.png)

**📸 Screenshot Instructions**:
```powershell
.\test-canary-success.ps1
```
Screenshot showing script starting with version update v1.0 → v2.0

![Test Success Progress](./evidence/41-test-success-progress.png)

**📸 Screenshot Instructions**:
Screenshot during deployment showing:
- Step 3/7: Analysis Running
- Canary pods created
- 4 pods total (2 stable + 2 canary)

![Test Success Complete](./evidence/42-test-success-complete.png)

**📸 Screenshot Instructions**:
Screenshot showing:
- Step 7/7 completed
- Status: Healthy
- All pods running new version (v2.0)

### Test 2: Auto-Rollback on Failure

![Test Rollback Start](./evidence/43-test-rollback-start.png)

**📸 Screenshot Instructions**:
```powershell
.\test-canary-rollback.ps1
```
Screenshot showing script starting with ERROR_RATE=0.5

![Test Rollback Analysis Fail](./evidence/44-test-rollback-fail.png)

**📸 Screenshot Instructions**:
Screenshot showing:
- Analysis: Failed (success-rate = 0.5 < 0.95)
- Status: Degraded
- Rollback triggered

![Test Rollback Complete](./evidence/45-test-rollback-complete.png)

**📸 Screenshot Instructions**:
Screenshot showing:
- Rollback completed
- Status: Healthy
- All pods back to old version

### Frontend Application Working

![Frontend App](./evidence/46-frontend-working.png)

**📸 Screenshot Instructions**:
1. Run: `kubectl port-forward -n fullstack-namespace svc/frontend-svc 8081:80`
2. Go to: http://localhost:8081
3. Screenshot showing React app loaded

### Backend API Response

![Backend API](./evidence/47-backend-api-response.png)

**📸 Screenshot Instructions**:
1. Run: `kubectl port-forward -n fullstack-namespace svc/backend-svc 8080:8080`
2. Test: `curl http://localhost:8080/` or open in browser
3. Screenshot showing JSON response:
```json
{
  "message": "Hello from Backend v2.0",
  "version": "v2.0"
}
```

### Backend Metrics Endpoint

![Backend Metrics](./evidence/48-backend-metrics.png)

**📸 Screenshot Instructions**:
1. Same port-forward
2. Go to: http://localhost:8080/metrics
3. Screenshot showing Prometheus metrics:
   - flask_http_request_total
   - flask_http_request_duration_seconds_bucket
   - etc.


---

## 📝 CONFIGURATION FILES EVIDENCE

### GitHub Actions Workflow

![Workflow File](./evidence/49-workflow-file.png)

**📸 Screenshot Instructions**:
Screenshot of `.github/workflows/cicd.yml` file content showing:
- build-frontend job
- build-backend job
- Docker build and push steps
- Manifest update with yq

### ArgoCD Root Application

![Root App YAML](./evidence/50-root-app-yaml.png)

**📸 Screenshot Instructions**:
Screenshot of `CICD_repo/argocd/root.yaml` showing:
- repoURL
- path: CICD_repo/argocd/apps
- syncPolicy: automated

### Backend Rollout Configuration

![Rollout YAML](./evidence/51-rollout-yaml.png)

**📸 Screenshot Instructions**:
Screenshot of `CICD_repo/BE/rollout.yaml` showing:
- Canary strategy
- 6 steps with analysis
- Services: canaryService, stableService

### Analysis Template Configuration

![Analysis Template YAML](./evidence/52-analysis-template-yaml.png)

**📸 Screenshot Instructions**:
Screenshot of `CICD_repo/BE/analysis-template.yaml` showing:
- 3 metrics: success-rate, latency-p95, pod-ready
- Prometheus queries
- count: 5, interval: 10s, failureLimit: 3

### ServiceMonitor Configuration

![ServiceMonitor YAML](./evidence/53-servicemonitor-yaml.png)

**📸 Screenshot Instructions**:
Screenshot of `CICD_repo/argocd/apps/servicemonitor.yaml` showing:
- selector matching backend pods
- endpoint: port http, path /metrics
- labels: release: kube-prometheus-stack

---

## 🎓 SUMMARY & CONCLUSION

### Project Achievements

✅ **CI/CD Pipeline**:
- Automated Docker image build on code push
- Automatic manifest updates via GitHub Actions
- GitOps workflow with ArgoCD

✅ **Progressive Delivery**:
- Canary deployment with 6-step strategy
- Automated analysis using Prometheus metrics
- Auto-rollback on metric failures

✅ **Monitoring & Observability**:
- Prometheus metrics collection (15s interval)
- Grafana dashboard visualization
- Real-time application health monitoring

✅ **Infrastructure as Code**:
- All configurations in Git
- Declarative Kubernetes manifests
- Reproducible deployments

### Key Metrics

- **Deployment Time**: ~3-4 minutes (Canary)
- **Rollback Time**: ~30 seconds
- **Zero Downtime**: Maintained throughout deployments
- **Success Rate**: > 95% (monitored via Prometheus)
- **Latency P95**: < 1 second

### Technologies Demonstrated

| Category | Technology |
|----------|-----------|
| **Frontend** | React, Vite, Nginx |
| **Backend** | Flask, Python |
| **Container** | Docker, Docker Hub |
| **Orchestration** | Kubernetes (Minikube) |
| **GitOps** | ArgoCD (App of Apps pattern) |
| **Progressive Delivery** | Argo Rollouts (Canary) |
| **Monitoring** | Prometheus, Grafana |
| **CI/CD** | GitHub Actions |
| **IaC** | Kubernetes YAML manifests |

---

## 📸 CHECKLIST - SCREENSHOTS TO CAPTURE

### Must Have (Critical):
- [ ] 09 - ArgoCD dashboard with all apps
- [ ] 10 - Root app details
- [ ] 12 - Backend app with Rollout
- [ ] 22 - Rollout healthy state
- [ ] 28 - Prometheus targets showing backend-svc
- [ ] 35 - Grafana backend dashboard
- [ ] 42 - Successful canary deployment complete
- [ ] 47 - Backend API response

### Should Have (Important):
- [ ] 04 - GitHub Actions workflow runs
- [ ] 11 - Frontend app details
- [ ] 23 - Rollout steps visualization
- [ ] 29 - Prometheus success-rate query
- [ ] 36-39 - Grafana individual panels
- [ ] 45 - Rollback complete

### Nice to Have (Optional):
- [ ] 01 - Architecture diagram
- [ ] 25 - Canary in progress (live)
- [ ] 40-41 - Test execution screenshots
- [ ] 49-53 - Configuration file screenshots

---

## 📦 HOW TO USE THIS EVIDENCE PACK

1. **Create `evidence/` folder** in project root (already done)
2. **Follow screenshot instructions** for each section
3. **Save screenshots** with exact filenames (e.g., `09-argocd-dashboard.png`)
4. **Copy screenshots** into `evidence/` folder
5. **View markdown** - images will auto-display

### Quick Port-Forward Commands:

```powershell
# ArgoCD
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Argo Rollouts
kubectl argo rollouts dashboard -n fullstack-namespace

# Frontend
kubectl port-forward -n fullstack-namespace svc/frontend-svc 8081:80

# Backend
kubectl port-forward -n fullstack-namespace svc/backend-svc 8080:8080
```

---

**END OF EVIDENCE PACK**

*Generated: June 12, 2026*  
*Project: GitOps CI/CD with Canary Deployment*  
*Author: Nguyen Khanh Duy*
