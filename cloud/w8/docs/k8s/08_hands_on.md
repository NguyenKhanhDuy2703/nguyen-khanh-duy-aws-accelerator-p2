# 08 — Hands-on Lab

> Thực hành toàn bộ concepts từ file 01-07 — deploy một web app hoàn chỉnh lên K8s.

---

## Mục tiêu

Cuối lab này bạn sẽ deploy được:

```
User → Service (LoadBalancer) → Deployment (3 replicas Nginx)
                                      ↓
                               ConfigMap (nginx config)
                               Secret (basic auth)
                               Liveness + Readiness Probe
                               NetworkPolicy (chỉ cho phép từ LB)
```

---

## Chuẩn bị

```bash
# Start minikube
minikube start --driver=docker

# Bật addon để dùng LoadBalancer locally
minikube addons enable metallb

# Tạo namespace riêng cho lab
kubectl create namespace lab

# Set default namespace (không cần gõ -n lab mỗi lần)
kubectl config set-context --current --namespace=lab

# Kiểm tra
kubectl get nodes
kubectl get pods --all-namespaces
```

---

## Bước 1 — ConfigMap

Tạo file `01-configmap.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: lab
data:
  APP_ENV: "development"
  APP_VERSION: "1.0.0"

  # Custom nginx config
  default.conf: |
    server {
        listen 80;
        server_name _;

        location / {
            root /usr/share/nginx/html;
            index index.html;
        }

        location /health {
            return 200 'ok';
            add_header Content-Type text/plain;
        }

        location /ready {
            return 200 'ready';
            add_header Content-Type text/plain;
        }
    }
```

```bash
kubectl apply -f 01-configmap.yaml
kubectl get configmap nginx-config
kubectl describe configmap nginx-config
```

---

## Bước 2 — Secret

Tạo file `02-secret.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: lab
type: Opaque
stringData:
  APP_SECRET_KEY: "dev-secret-key-change-in-prod"
  DB_PASSWORD: "localdev123"
```

```bash
kubectl apply -f 02-secret.yaml

# Xem Secret (values ẩn)
kubectl get secret app-secrets
kubectl describe secret app-secrets

# Decode thủ công để kiểm tra
kubectl get secret app-secrets -o jsonpath='{.data.DB_PASSWORD}' | base64 --decode
```

---

## Bước 3 — Deployment với Probes

Tạo file `03-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: lab
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
        version: "1.0"
    spec:
      containers:
      - name: nginx
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80

        # Inject config từ ConfigMap
        envFrom:
        - configMapRef:
            name: nginx-config
        - secretRef:
            name: app-secrets

        # Mount nginx config file
        volumeMounts:
        - name: nginx-config-volume
          mountPath: /etc/nginx/conf.d/
          readOnly: true

        # Resource limits
        resources:
          requests:
            memory: "32Mi"
            cpu: "50m"
          limits:
            memory: "64Mi"
            cpu: "100m"

        # Startup Probe
        startupProbe:
          httpGet:
            path: /health
            port: 80
          failureThreshold: 10
          periodSeconds: 3

        # Liveness Probe
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          periodSeconds: 20
          failureThreshold: 3

        # Readiness Probe
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          periodSeconds: 10
          failureThreshold: 3

      volumes:
      - name: nginx-config-volume
        configMap:
          name: nginx-config
          items:
          - key: default.conf
            path: default.conf
```

```bash
kubectl apply -f 03-deployment.yaml

# Theo dõi quá trình tạo Pods
kubectl get pods -w

# Xem chi tiết một Pod (kiểm tra Probes đã được config chưa)
kubectl describe pod -l app=web-app | grep -A 10 "Liveness\|Readiness\|Startup"

# Xem logs
kubectl logs -l app=web-app --prefix
```

---

## Bước 4 — Service


Tạo file `04-service.yaml`:

```yaml
# ClusterIP cho internal traffic
apiVersion: v1
kind: Service
metadata:
  name: web-app-internal
  namespace: lab
spec:
  type: ClusterIP
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
---
# LoadBalancer để expose ra ngoài
apiVersion: v1
kind: Service
metadata:
  name: web-app-lb
  namespace: lab
spec:
  type: LoadBalancer
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
```

```bash
kubectl apply -f 04-service.yaml
kubectl get services

# Với minikube, dùng lệnh này để lấy URL
minikube service web-app-lb -n lab --url

# Test
curl $(minikube service web-app-lb -n lab --url)/health
curl $(minikube service web-app-lb -n lab --url)/ready
```

---

## Bước 5 — NetworkPolicy

Tạo file `05-netpol.yaml`:

```yaml
# Deny all ingress trong namespace lab
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: lab
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
# Chỉ cho phép traffic từ bên ngoài vào web-app
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-external-to-web
  namespace: lab
spec:
  podSelector:
    matchLabels:
      app: web-app
  policyTypes:
  - Ingress
  ingress:
  - ports:
    - protocol: TCP
      port: 80
```

```bash
kubectl apply -f 05-netpol.yaml
kubectl get networkpolicies

# Test: web-app vẫn accessible
curl $(minikube service web-app-lb -n lab --url)/health
```

---

## Bước 6 — Thực hành Scaling và Rolling Update

```bash
# Scale lên 5 replicas
kubectl scale deployment web-app --replicas=5
kubectl get pods -w   # Quan sát Pods mới được tạo

# Scale xuống 2
kubectl scale deployment web-app --replicas=2
kubectl get pods -w   # Quan sát Pods bị xóa

# Rolling update — đổi image version
kubectl set image deployment/web-app nginx=nginx:1.26-alpine
kubectl rollout status deployment/web-app  # Theo dõi tiến trình

# Xem lịch sử
kubectl rollout history deployment/web-app

# Rollback về version trước
kubectl rollout undo deployment/web-app
kubectl rollout status deployment/web-app
```

---

## Bước 7 — Simulate Pod crash

```bash
# Tìm tên một Pod
kubectl get pods

# Xóa Pod thủ công
kubectl delete pod <pod-name>

# Quan sát Deployment tự tạo lại Pod
kubectl get pods -w
```

---

## Bước 8 — Debug kỹ năng

```bash
# Exec vào container
kubectl exec -it deployment/web-app -- /bin/sh

# Bên trong container, kiểm tra env vars từ ConfigMap/Secret
echo $APP_ENV
echo $DB_PASSWORD

# Kiểm tra file config đã mount chưa
cat /etc/nginx/conf.d/default.conf

exit

# Xem events của namespace (hữu ích khi debug)
kubectl get events --sort-by='.lastTimestamp'

# Top resource usage
kubectl top pods
kubectl top nodes
```

---

## Dọn dẹp

```bash
# Xóa toàn bộ resources trong namespace
kubectl delete namespace lab

# Hoặc xóa từng file
kubectl delete -f 05-netpol.yaml
kubectl delete -f 04-service.yaml
kubectl delete -f 03-deployment.yaml
kubectl delete -f 02-secret.yaml
kubectl delete -f 01-configmap.yaml

# Stop minikube
minikube stop
```

---

## kubectl Cheat Sheet

```bash
# Get resources
kubectl get pods,svc,deploy,cm,secret,netpol

# Describe (chi tiết + events)
kubectl describe pod <name>

# Logs
kubectl logs <pod> -f --previous

# Exec
kubectl exec -it <pod> -- /bin/sh

# Apply / Delete
kubectl apply -f file.yaml
kubectl delete -f file.yaml

# Scale
kubectl scale deployment <name> --replicas=N

# Rolling update
kubectl set image deployment/<name> <container>=<image>
kubectl rollout status/history/undo deployment/<name>

# Port forward (test nhanh không cần Service)
kubectl port-forward pod/<name> 8080:80
kubectl port-forward svc/<name> 8080:80
```

---

## Tổng kết Series

Bạn đã hoàn thành:

- [x] Hiểu Container và sự khác biệt với VM
- [x] Nắm K8s Architecture — Control Plane vs Worker Node
- [x] Pod — ephemeral, resources, Deployment
- [x] ConfigMap & Secret — tách config ra khỏi code
- [x] Service — ClusterIP, NodePort, LoadBalancer
- [x] Probes — Liveness, Readiness, Startup
- [x] NetworkPolicy — zero-trust networking
- [x] Thực hành deploy, scale, rolling update, rollback

**Bước tiếp theo:**
- **Ingress** — một LB cho nhiều services, routing theo path/host
- **PersistentVolume** — lưu data bền vững cho Pod
- **HorizontalPodAutoscaler** — tự động scale dựa trên CPU/memory
- **Helm** — package manager cho K8s
- **CKAD certification** — chứng chỉ K8s cho developers
