# 🏗️ TỔNG QUAN LUỒNG DỰ ÁN - FULLSTACK APP WITH GITOPS & CANARY DEPLOYMENT

## 📚 MỤC LỤC
1. [Kiến trúc tổng quan](#kiến-trúc-tổng-quan)
2. [Các thành phần chính](#các-thành-phần-chính)
3. [Luồng CI/CD Pipeline](#luồng-cicd-pipeline)
4. [Luồng GitOps với ArgoCD](#luồng-gitops-với-argocd)
5. [Luồng Canary Deployment](#luồng-canary-deployment)
6. [Luồng Monitoring](#luồng-monitoring)
7. [Luồng hoàn chỉnh từ Code đến Production](#luồng-hoàn-chỉnh)

---

## 🎯 KIẾN TRÚC TỔNG QUAN {#kiến-trúc-tổng-quan}

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          DEVELOPER WORKFLOW                              │
│                                                                          │
│  Developer → Git Push → GitHub → GitHub Actions → Docker Hub            │
│                                        ↓                                 │
│                              Update K8s Manifests                        │
│                                        ↓                                 │
│                              Git Push to Main Branch                     │
└─────────────────────────────────────────────────────────────────────────┘
                                        ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                          GITOPS WORKFLOW (ArgoCD)                        │
│                                                                          │
│  ArgoCD monitors GitHub repo → Detect manifest changes →                │
│  Auto-sync to Kubernetes cluster                                        │
└─────────────────────────────────────────────────────────────────────────┘
                                        ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                      KUBERNETES CLUSTER (Minikube)                       │
│                                                                          │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐     │
│  │   Namespace:     │  │   Namespace:     │  │   Namespace:     │     │
│  │   argocd         │  │   monitoring     │  │   argo-rollouts  │     │
│  ├──────────────────┤  ├──────────────────┤  ├──────────────────┤     │
│  │ - ArgoCD Server  │  │ - Prometheus     │  │ - Rollouts       │     │
│  │ - App Controller │  │ - Grafana        │  │   Controller     │     │
│  │ - Root App       │  │ - Alertmanager   │  │ - Dashboard      │     │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘     │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐     │
│  │         Namespace: fullstack-namespace                         │     │
│  ├────────────────────────────────────────────────────────────────┤     │
│  │  FRONTEND (Deployment)          BACKEND (Rollout)             │     │
│  │  ├─ frontend-deploy             ├─ backend-rollout            │     │
│  │  │  ├─ Pod 1 (React)            │  ├─ Stable ReplicaSet      │     │
│  │  │  └─ Pod 2 (React)            │  │  ├─ Pod 1 (Flask v1.0)  │     │
│  │  └─ frontend-svc                │  │  └─ Pod 2 (Flask v1.0)  │     │
│  │                                  │  ├─ Canary ReplicaSet      │     │
│  │                                  │  │  ├─ Pod 3 (Flask v2.0)  │     │
│  │                                  │  │  └─ Pod 4 (Flask v2.0)  │     │
│  │                                  │  ├─ backend-svc (Stable)   │     │
│  │                                  │  └─ backend-canary-svc     │     │
│  │                                                                │     │
│  │  MONITORING                      ANALYSIS                      │     │
│  │  ├─ ServiceMonitor              ├─ AnalysisTemplate           │     │
│  │  └─ Grafana Dashboard           └─ AnalysisRun (runtime)      │     │
│  └────────────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 🧩 CÁC THÀNH PHẦN CHÍNH {#các-thành-phần-chính}

### 1. **Source Code Repositories**

- **GitHub Repository**: `nguyen-khanh-duy-aws-accelerator-p2`
  - `CICD_repo/FE/src/` - Frontend React code
  - `CICD_repo/BE/app.py` - Backend Flask code
  - `CICD_repo/FE/*.yaml` - Frontend K8s manifests
  - `CICD_repo/BE/*.yaml` - Backend K8s manifests
  - `CICD_repo/argocd/` - ArgoCD Application definitions
  - `.github/workflows/cicd.yml` - GitHub Actions CI/CD pipeline

### 2. **CI/CD Pipeline (GitHub Actions)**

- **Trigger**: Push to `main` branch (FE or BE code changes)
- **Jobs**:
  - `build-frontend`: Build FE Docker image → Push to Docker Hub → Update manifest
  - `build-backend`: Build BE Docker image → Push to Docker Hub → Update manifest

### 3. **Container Registry**

- **Docker Hub**: `nkd7059181/`
  - `frontend:latest` và `frontend:<git-sha>`
  - `backend:latest` và `backend:<git-sha>`

### 4. **GitOps Engine (ArgoCD)**

**Namespace**: `argocd`

**Components**:
- **Root Application** (`root-app-manager`)
  - Quản lý tất cả child applications
  - Monitors: `CICD_repo/argocd/apps/`
  
- **Child Applications**:
  1. `frontend-dev` - Deploy Frontend
  2. `backend-dev` - Deploy Backend
  3. `kube-prometheus-stack` - Monitoring stack
  4. `argo-rollouts` - Canary deployment controller
  5. `servicemonitor` - Prometheus scrape config
  6. `grafana-backend-dashboard` - Grafana dashboard

**Sync Policy**: Automated (prune + selfHeal enabled)

### 5. **Kubernetes Cluster (Minikube)**

**Namespaces**:

| Namespace | Purpose | Components |
|-----------|---------|------------|
| `argocd` | GitOps engine | ArgoCD server, controllers, Root App |
| `monitoring` | Observability | Prometheus, Grafana, Alertmanager |
| `argo-rollouts` | Progressive delivery | Rollouts controller, Dashboard |
| `fullstack-namespace` | Application workloads | Frontend pods, Backend pods, Services |

### 6. **Application Components**

**Frontend**:
- **Technology**: React + Vite
- **Deployment**: Standard Kubernetes Deployment (2 replicas)
- **Service**: ClusterIP on port 80
- **Nginx**: Reverse proxy to Backend

**Backend**:
- **Technology**: Flask (Python)
- **Deployment**: Argo Rollout (Canary strategy, 2 replicas)
- **Services**: 
  - `backend-svc` (Stable traffic)
  - `backend-canary-svc` (Canary traffic)
- **Metrics**: Prometheus metrics at `/metrics`
- **Environment Variables**:
  - `VERSION`: App version (e.g., v1.0, v2.0)
  - `ERROR_RATE`: Simulated error rate for testing (0-1)

### 7. **Progressive Delivery (Argo Rollouts)**

**Strategy**: Canary Deployment with Analysis

**Steps**:
1. Deploy 20% canary → Pause 30s → Analysis
2. Deploy 50% canary → Pause 30s → Analysis
3. Deploy 100% (full rollout)

**Analysis Metrics** (via Prometheus):
- `success-rate`: ≥ 95% (HTTP 2xx/3xx responses)
- `latency-p95`: < 1 second (P95 response time)
- `pod-ready`: ≥ 1 (At least 1 pod ready)

**Auto-Rollback**: If any metric fails 3 times → Abort and rollback

### 8. **Monitoring Stack (Kube-Prometheus-Stack)**

**Components**:
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Alertmanager**: Alert routing and management

**ServiceMonitor**:
- Scrapes Backend pods every 15s
- Endpoint: `http://<pod-ip>:8080/metrics`
- Labels: `release: kube-prometheus-stack`, `app: backend`

**Grafana Dashboard**: "Backend Application Monitoring"
- HTTP Request Rate
- Error Rate (%)
- Response Time (P50, P95)
- Memory Usage
- Pod Status

---

## 🔄 LUỒNG CI/CD PIPELINE {#luồng-cicd-pipeline}

### Pipeline Trigger

```
Developer → Code changes → Git push to main
                              ↓
                    GitHub detects changes
                              ↓
                GitHub Actions workflow triggered
```

### Frontend Build Flow

```
Step 1: Checkout code
        ├─ actions/checkout@v4
        └─ Clone repo to runner

Step 2: Docker Login
        ├─ docker/login-action@v3
        └─ Authenticate with Docker Hub

Step 3: Build & Push Docker Image
        ├─ docker build -t nkd7059181/frontend:latest
        ├─ docker build -t nkd7059181/frontend:<git-sha>
        ├─ docker push nkd7059181/frontend:latest
        └─ docker push nkd7059181/frontend:<git-sha>

Step 4: Update K8s Manifest
        ├─ Install yq (YAML processor)
        ├─ yq -i '.spec.template.spec.containers[0].image = "..."' FE/deployment.yaml
        ├─ Update image tag to <git-sha>
        ├─ git commit -m "Update FE image to <git-sha>"
        └─ git push to main

Result: New image in Docker Hub + Updated manifest in Git
```

### Backend Build Flow

```
Step 1-3: Same as Frontend (Checkout, Login, Build & Push)
          Image: nkd7059181/backend:latest and backend:<git-sha>

Step 4: Update K8s Manifest
        ├─ yq -i '.spec.template.spec.containers[0].image = "..."' BE/deployment.yaml
        ├─ Update image tag to <git-sha>
        ├─ git commit -m "Update BE image to <git-sha>"
        └─ git push to main

Result: New image in Docker Hub + Updated manifest in Git
```

**Lưu ý quan trọng**:
- Pipeline commit lại manifest file → Trigger ArgoCD sync
- Không deploy trực tiếp vào cluster → Tuân thủ GitOps principles
- Image tag sử dụng Git SHA → Traceable và immutable

---

## 🔄 LUỒNG GITOPS VỚI ARGOCD {#luồng-gitops-với-argocd}

### ArgoCD Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      ArgoCD Namespace                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │           Root Application (App of Apps)             │   │
│  │  Name: root-app-manager                              │   │
│  │  Monitors: CICD_repo/argocd/apps/*.yaml              │   │
│  └──────────────────────────────────────────────────────┘   │
│                          │                                   │
│                          ├─────────────┬─────────────┐       │
│                          │             │             │       │
│  ┌───────────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐│
│  │ frontend-dev  │  │backend-dev│ │prometheus│  │rollouts ││
│  │ Application   │  │Application│  │  stack   │  │  ctrl   ││
│  └───────────────┘  └───────────┘  └──────────┘  └─────────┘│
└─────────────────────────────────────────────────────────────┘
```

### GitOps Sync Flow

**Khi manifest thay đổi trên GitHub**:

```
1. GitHub Actions commit manifest changes
                ↓
2. ArgoCD poll GitHub repo mỗi 3 phút (hoặc webhook)
                ↓
3. ArgoCD detect changes
   - Compare: Git desired state vs Cluster live state
   - Status: OutOfSync
                ↓
4. Auto-Sync triggered (syncPolicy.automated = true)
   - Apply changes to Kubernetes cluster
   - Create/Update/Delete resources
                ↓
5. Health Check
   - Wait for pods to be Ready
   - Verify Deployment/Rollout status
                ↓
6. Sync Complete
   - Status: Synced + Healthy
```

### App-of-Apps Pattern

**Root App** (`root-app-manager`):
- Source: `CICD_repo/argocd/apps/`
- Destination: `argocd` namespace
- Manages 6 child applications

**Child Apps**:
1. **frontend-dev**
   - Source: `CICD_repo/FE/*.yaml`
   - Destination: `fullstack-namespace`
   - Deploys: Deployment, Service, ConfigMap
