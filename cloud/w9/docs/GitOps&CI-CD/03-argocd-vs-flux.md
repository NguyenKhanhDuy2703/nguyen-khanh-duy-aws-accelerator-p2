# 03 — ArgoCD vs Flux: So sánh 2 GitOps Engine

> Cả hai đều là CNCF Graduated projects — đều production-ready.  
> Sự khác biệt nằm ở triết lý thiết kế và trải nghiệm vận hành.

---

## So sánh nhanh

| Tiêu chí | ArgoCD | Flux |
|---|---|---|
| **Giao diện** | Web UI đẹp, trực quan | CLI-first, không có UI mặc định |
| **Kiến trúc** | Monolithic (1 binary nhiều tính năng) | Modular (nhiều controller nhỏ) |
| **Cài đặt** | 2 lệnh `kubectl apply` | `flux bootstrap` |
| **RBAC** | Built-in, chi tiết | Dựa vào Kubernetes RBAC |
| **Multi-cluster** | Native, từ 1 control plane | Mỗi cluster cần 1 Flux instance |
| **Resource usage** | Nặng hơn (~500MB RAM) | Nhẹ hơn (~200MB RAM) |
| **SSO** | Built-in (OIDC, SAML, GitHub OAuth) | Cần tự cấu hình |
| **Sync waves** | Có (`sync-wave` annotation) | Có (`dependsOn` field) |
| **Notification** | ArgoCD Notifications built-in | Notification Controller riêng |
| **Helm support** | Tốt | Tốt hơn (HelmRelease CRD native) |

---

## ArgoCD — Phù hợp khi nào?

### Thế mạnh

**1. Web UI là điểm mạnh số 1**

```mermaid
graph TB
    UI["🖥️ ArgoCD Web UI"]
    
    TREE["📊 Resource Tree View<br/><small>Pod, Service, Ingress...</small>"]
    DIFF["🔍 Diff Viewer<br/><small>desired vs actual</small>"]
    SYNC["🔄 One-click Sync"]
    HISTORY["📜 Sync History<br/><small>& Rollback</small>"]
    APPS["📱 Multi-app Dashboard"]
    
    UI --> TREE
    UI --> DIFF
    UI --> SYNC
    UI --> HISTORY
    UI --> APPS
    
    style UI fill:#e3f2fd,stroke:#1976d2,stroke-width:3px
    style TREE fill:#e8f5e9,stroke:#388e3c
    style DIFF fill:#fff3e0,stroke:#f57c00
    style SYNC fill:#e1f5fe,stroke:#0288d1
    style HISTORY fill:#f3e5f5,stroke:#7b1fa2
    style APPS fill:#fce4ec,stroke:#c2185b
```

**2. App-of-Apps pattern** — quản lý hàng trăm app từ 1 root Application (xem file 04).

**3. Multi-tenant với Projects**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-backend
spec:
  sourceRepos:
    - 'https://github.com/myorg/backend-*'   # chỉ được deploy từ repo này
  destinations:
    - namespace: backend-*                    # chỉ được deploy vào namespace backend
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
```

**Chọn ArgoCD khi:**
- Team cần visibility cao — PM, SRE, manager xem được deployment status
- Multi-tenant: nhiều team dùng chung 1 cluster
- Muốn onboard nhanh — UI giúp junior devs hiểu được GitOps ngay
- Quản lý nhiều app phức tạp với dependency

---

## Flux — Phù hợp khi nào?

### Thế mạnh

**1. Kubernetes-native 100%** — mọi thứ là CRD

```yaml
# Flux dùng CRD thay vì UI clicks
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: my-app
spec:
  interval: 1m
  url: https://github.com/myorg/my-app
  ref:
    branch: main
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: my-app
spec:
  interval: 10m
  path: ./k8s
  prune: true
  sourceRef:
    kind: GitRepository
    name: my-app
```

**2. Modular — chỉ cài những gì cần**

```mermaid
graph TB
    subgraph FLUX["🔷 Flux Toolkit Architecture"]
        SOURCE["📦 source-controller<br/><small>watch Git/Helm/OCI repos</small>"]
        KUSTOMIZE["⚙️ kustomize-controller<br/><small>apply Kustomize manifests</small>"]
        HELM["📊 helm-controller<br/><small>manage Helm releases</small>"]
        NOTIF["🔔 notification-controller<br/><small>alerts</small>"]
        IMAGE["🖼️ image-automation-controller<br/><small>tự update image tags</small>"]
        
        SOURCE --> KUSTOMIZE
        SOURCE --> HELM
        KUSTOMIZE --> NOTIF
        HELM --> NOTIF
        IMAGE --> SOURCE
    end
    
    GIT["📁 Git Repository"] --> SOURCE
    K8S["☸️ Kubernetes API"] 
    KUSTOMIZE --> K8S
    HELM --> K8S
    
    style FLUX fill:#e8f5e9,stroke:#388e3c
    style SOURCE fill:#fff3e0,stroke:#f57c00
    style KUSTOMIZE fill:#e1f5fe,stroke:#0288d1
    style HELM fill:#f3e5f5,stroke:#7b1fa2
    style NOTIF fill:#fce4ec,stroke:#c2185b
    style IMAGE fill:#fff9c4,stroke:#f9a825
    style GIT fill:#e3f2fd,stroke:#1976d2
    style K8S fill:#c8e6c9,stroke:#388e3c
```

**3. Air-gapped environments** — không cần internet access từ cluster, chỉ cần Git server nội bộ.

**4. Helm-native hơn** — `HelmRelease` CRD cho phép quản lý Helm lifecycle hoàn chỉnh.

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: podinfo
spec:
  interval: 5m
  chart:
    spec:
      chart: podinfo
      version: '>=6.0.0'
      sourceRef:
        kind: HelmRepository
        name: podinfo
  values:
    replicaCount: 2
```

**Chọn Flux khi:**
- Platform team, SRE chuyên nghiệp — ổn với CLI
- Resource bị giới hạn (edge cluster, IoT, small VM)
- Air-gapped hoặc strict network isolation
- Helm-heavy workloads
- Muốn mọi thứ là Kubernetes native (GitOps repo = single source of truth cho config)

---

## Điểm giống nhau quan trọng

Cả hai đều:

- Là CNCF Graduated (production-ready, có long-term support)
- Hỗ trợ Kubernetes manifests, Helm, Kustomize
- Có reconciliation loop (phát hiện và sửa drift)
- Hỗ trợ progressive delivery khi kết hợp với Argo Rollouts / Flagger
- Có notification (Slack, PagerDuty, etc.)
- Hỗ trợ multi-cluster (cách khác nhau)

---

## Hybrid pattern — dùng cả hai

Một số enterprise dùng cả hai theo phân chia rõ ràng:

```mermaid
graph TB
    subgraph PLATFORM["🏢 Platform Hub Cluster"]
        ARGOCD["🎯 ArgoCD<br/><small>quản lý app deployments</small>"]
        DEVS["👨‍💻 Developers<br/><small>thấy UI đẹp, tracking apps</small>"]
        ARGOCD --> DEVS
    end
    
    subgraph DEV["🔧 Dev Cluster"]
        FLUX_DEV["🔷 Flux<br/><small>quản lý infra components</small>"]
        INFRA_DEV["cert-manager<br/>ingress-nginx<br/>prometheus-stack"]
        FLUX_DEV --> INFRA_DEV
    end
    
    subgraph STAGING["🧪 Staging Cluster"]
        FLUX_STG["🔷 Flux<br/><small>quản lý infra components</small>"]
        INFRA_STG["cert-manager<br/>ingress-nginx<br/>prometheus-stack"]
        FLUX_STG --> INFRA_STG
    end
    
    subgraph PROD["🚀 Production Cluster"]
        FLUX_PROD["🔷 Flux<br/><small>quản lý infra components</small>"]
        INFRA_PROD["cert-manager<br/>ingress-nginx<br/>prometheus-stack"]
        FLUX_PROD --> INFRA_PROD
    end
    
    ARGOCD -.->|"deploy apps to"| DEV
    ARGOCD -.->|"deploy apps to"| STAGING
    ARGOCD -.->|"deploy apps to"| PROD
    
    style PLATFORM fill:#e3f2fd,stroke:#1976d2
    style ARGOCD fill:#bbdefb,stroke:#1976d2
    style DEV fill:#fff3e0,stroke:#f57c00
    style STAGING fill:#f3e5f5,stroke:#7b1fa2
    style PROD fill:#e8f5e9,stroke:#388e3c
    style FLUX_DEV fill:#ffecb3,stroke:#f57c00
    style FLUX_STG fill:#f3e5f5,stroke:#7b1fa2
    style FLUX_PROD fill:#c8e6c9,stroke:#388e3c
```

**Nguyên tắc:** ArgoCD và Flux không được watch cùng 1 directory trong Git — sẽ conflict.

---

## Kết luận cho W9 lab

Trong lab W9, bạn sẽ dùng **ArgoCD** vì:

1. Web UI giúp bạn nhìn thấy trực quan ArgoCD đang làm gì
2. App-of-Apps pattern dễ hiểu hơn với beginners
3. Community lớn hơn → dễ tìm tutorial và troubleshoot
4. Sync waves và hooks được document rõ hơn

---

*File tiếp theo: [04-argocd-deep-dive.md](./04-argocd-deep-dive.md)*
