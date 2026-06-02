# 07 — NetworkPolicy

> Mặc định mọi Pod nói chuyện tự do với nhau — NetworkPolicy đặt tường lửa giữa chúng.

---

## Vấn đề: Flat Network mặc định

Trong K8s không cấu hình gì thêm, mọi Pod có thể giao tiếp với **bất kỳ Pod nào khác** trong cluster — kể cả khác namespace.

```
Pod frontend  →  Pod backend    ✓ (hợp lý)
Pod frontend  →  Pod database   ✓ (nguy hiểm — sao frontend cần gọi DB trực tiếp?)
Pod backend   →  Pod monitoring ✓ (không cần thiết)
Pod A         →  Pod B (khác team, khác namespace) ✓ (không kiểm soát được)
```

Nếu một Pod bị compromise (hacker vào được), nó có thể **lateral move** — tấn công sang mọi Pod khác trong cluster. Đây là rủi ro bảo mật lớn.

**NetworkPolicy** là giải pháp — hoạt động như **firewall Layer 3/4** cho Pod.

---

## NetworkPolicy là gì?

NetworkPolicy là K8s object định nghĩa **traffic rules** cho Pods: Pod nào được gọi vào (ingress), Pod nào được gọi ra (egress).

> **Quan trọng:** NetworkPolicy chỉ hoạt động nếu CNI (Container Network Interface) plugin hỗ trợ. Calico, Cilium, Weave Net đều hỗ trợ. Flannel mặc định **không hỗ trợ**. Kiểm tra CNI của cluster trước khi dùng.

---

## Nguyên tắc hoạt động

**Mặc định:** Không có NetworkPolicy nào → tất cả traffic được phép (allow all).

**Khi có NetworkPolicy áp dụng cho Pod:** Policy đó **thay thế** default allow. Chỉ traffic được khai báo tường minh mới được phép — còn lại đều bị từ chối.

Nhiều NetworkPolicy áp dụng cho cùng một Pod → các rules được **OR** với nhau (union).

---

## Deny All — Bắt đầu từ đây

Best practice: **deny all trước, whitelist sau**.

```yaml
# Deny tất cả ingress traffic vào namespace production
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: production
spec:
  podSelector: {}          # {} = áp dụng cho TẤT CẢ pods trong namespace
  policyTypes:
  - Ingress                # Chỉ rule ingress, không ảnh hưởng egress
```

Sau khi apply, không Pod nào trong namespace `production` nhận được traffic từ bên ngoài — kể cả trong cluster. Bây giờ mở dần từng đường cần thiết.

---

## Allow Ingress — Chỉ định ai được gọi vào

### Cho phép frontend gọi backend

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend           # Rule này áp dụng cho Pods có label app=backend

  policyTypes:
  - Ingress

  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend      # Chỉ cho phép Pods có label app=frontend gọi vào
    ports:
    - protocol: TCP
      port: 8080
```

Kết quả:
```
Pod frontend (app=frontend) → Pod backend :8080   ✓ ALLOW
Pod database (app=database) → Pod backend :8080   ✗ DENY
Pod monitoring              → Pod backend :8080   ✗ DENY
```

### Cho phép từ namespace khác

```yaml
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        name: monitoring         # Namespace có label name=monitoring
    podSelector:
      matchLabels:
        app: prometheus          # Chỉ Pod prometheus trong namespace đó
```

> **Chú ý cú pháp:** `namespaceSelector` và `podSelector` trong cùng một `-` item (list element) → AND logic (cả hai điều kiện phải đúng). Nếu tách thành hai `-` item riêng → OR logic.

```yaml
# AND: Pod là prometheus VÀ thuộc namespace monitoring
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        name: monitoring
    podSelector:            # ← cùng item, không có dấu -
      matchLabels:
        app: prometheus

# OR: Pod là prometheus HOẶC Pod thuộc namespace monitoring
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        name: monitoring
  - podSelector:            # ← item riêng biệt
      matchLabels:
        app: prometheus
```

---

## Egress — Kiểm soát traffic đi ra

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-egress
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend

  policyTypes:
  - Egress

  egress:
  # Cho phép gọi ra database
  - to:
    - podSelector:
        matchLabels:
          app: postgres
    ports:
    - protocol: TCP
      port: 5432

  # Cho phép DNS lookup (bắt buộc phải có nếu apply egress rule)
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```

> **DNS rule quan trọng:** Nếu bạn apply Egress NetworkPolicy mà quên allow DNS (port 53), mọi DNS lookup đều thất bại → app không resolve được hostname nào → lỗi connection mọi nơi. Luôn thêm DNS egress rule.

---

## Pattern thực tế: 3-tier Architecture

```
Internet → [Ingress] → Frontend (port 3000)
                           ↓
                       Backend (port 8080)
                           ↓
                       Database (port 5432)
```

```yaml
# 1. Deny all ingress trong namespace
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: production
spec:
  podSelector: {}
  policyTypes: [Ingress]

# 2. Frontend nhận traffic từ Ingress controller
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-to-frontend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes: [Ingress]
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-nginx

# 3. Backend chỉ nhận từ frontend
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - port: 8080

# 4. Database chỉ nhận từ backend
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-database
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: postgres
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - port: 5432
```

---

## Debug NetworkPolicy

```bash
# Xem NetworkPolicies trong namespace
kubectl get networkpolicies -n production

# Chi tiết policy
kubectl describe networkpolicy allow-frontend-to-backend -n production

# Test connectivity từ Pod này sang Pod kia
kubectl exec -it pod/frontend -- curl http://backend-svc:8080/health
kubectl exec -it pod/frontend -- curl http://postgres-svc:5432  # Phải bị từ chối
```

---

## Kiểm tra hiểu biết

1. Khi không có NetworkPolicy, traffic giữa các Pods được xử lý như thế nào?
2. Tại sao phải thêm DNS egress rule khi apply Egress NetworkPolicy?
3. Sự khác biệt giữa AND và OR khi kết hợp `namespaceSelector` và `podSelector`?

---

**Tiếp theo:** [08_hands_on.md](./08_hands_on.md) — Lab thực hành toàn bộ các concepts trên.
