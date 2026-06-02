# 04 — ConfigMap & Secret

> Tách cấu hình ra khỏi code — nguyên tắc 12-factor app trong K8s.

---

## Tại sao không hardcode config?

```dockerfile
# BAD — config nằm trong image
ENV DB_HOST=prod-db.internal
ENV DB_PASS=super_secret_123
```

Nếu làm vậy:
- Muốn deploy sang môi trường khác (dev/staging) → phải build image khác
- Secrets bị bake vào image → bất kỳ ai pull image là thấy password
- Thay đổi config → phải build lại toàn bộ image

**Giải pháp:** Tách config ra thành object riêng trong K8s — **ConfigMap** cho config thường, **Secret** cho thông tin nhạy cảm.

---

## ConfigMap

Lưu trữ cấu hình dạng **plain-text key-value** — không mã hóa.

### Tạo ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  # Key-value đơn giản
  APP_ENV: "production"
  DB_HOST: "postgres.internal"
  DB_PORT: "5432"
  LOG_LEVEL: "info"

  # Hoặc cả file config
  app.properties: |
    server.port=8080
    cache.ttl=300
    feature.dark-mode=true
```

### Dùng ConfigMap trong Pod — Cách 1: Environment Variables

```yaml
spec:
  containers:
  - name: app
    image: myapp:1.0
    env:
    # Inject từng key
    - name: APP_ENV
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: APP_ENV

    # Hoặc inject tất cả keys cùng lúc
    envFrom:
    - configMapRef:
        name: app-config
```

### Dùng ConfigMap trong Pod — Cách 2: Mount thành file

```yaml
spec:
  containers:
  - name: app
    image: myapp:1.0
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config      # File config sẽ xuất hiện ở đây

  volumes:
  - name: config-volume
    configMap:
      name: app-config            # Mount toàn bộ ConfigMap thành files
```

Kết quả: trong container sẽ có file `/etc/config/app.properties` với nội dung từ ConfigMap.

> **Env vars vs Volume mount?** Dùng env vars khi app đọc config qua environment. Dùng volume khi app đọc file config (nginx.conf, application.yml...). Volume mount có lợi thêm: khi update ConfigMap, file trong container **tự động cập nhật** (sau ~1 phút) mà không cần restart Pod — env vars thì không.

---

## Secret

Lưu thông tin nhạy cảm — passwords, API keys, TLS certificates. Về bản chất **Secret được encode Base64**, không phải encrypt.

```
"my-password" → base64 → "bXktcGFzc3dvcmQ="
```

Base64 không phải bảo mật — decode lại ngay lập tức. Bảo mật thật sự đến từ **RBAC** (chỉ người có quyền mới list/get Secret) và **encryption at rest** (etcd encrypt Secret trước khi lưu).

### Tạo Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
data:
  # Values phải encode base64: echo -n "value" | base64
  DB_PASSWORD: "c3VwZXJfc2VjcmV0XzEyMw=="
  API_KEY: "YWJjZGVmZ2hpams="
```

Hoặc dùng `stringData` để K8s tự encode:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
stringData:           # ← plain text, K8s tự encode khi lưu
  DB_PASSWORD: "super_secret_123"
  API_KEY: "abcdefghijk"
```

### Dùng Secret trong Pod

```yaml
spec:
  containers:
  - name: app
    image: myapp:1.0

    # Cách 1: Inject từng key
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: DB_PASSWORD

    # Cách 2: Inject tất cả
    envFrom:
    - secretRef:
        name: app-secrets

    # Cách 3: Mount thành file (khuyến nghị cho TLS certs)
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secrets
      readOnly: true

  volumes:
  - name: secret-volume
    secret:
      secretName: app-secrets
```

---

## So sánh ConfigMap vs Secret

| | ConfigMap | Secret |
|-|-----------|--------|
| **Dùng cho** | Config thường (URLs, feature flags) | Passwords, API keys, certs |
| **Encoding** | Plain text | Base64 |
| **Encryption** | Không | Có thể (etcd encryption at rest) |
| **Hiển thị** | `kubectl get configmap -o yaml` | `kubectl get secret` ẩn values |
| **Git** | Có thể commit | **Không bao giờ commit** |

---

## Best Practices

**Không commit Secret vào Git.** Dùng các giải pháp:
- **AWS Secrets Manager** + External Secrets Operator — sync secret từ AWS vào K8s
- **Sealed Secrets** — mã hóa Secret bằng public key, chỉ cluster mới decrypt được
- **Vault** (HashiCorp) — secret management chuyên dụng

**Principle of Least Privilege với RBAC:**

```yaml
# Chỉ cho phép service account đọc secret cụ thể
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["app-secrets"]   # Chỉ secret này
  verbs: ["get"]                   # Chỉ đọc, không list, không delete
```

---

## Kiểm tra hiểu biết

1. Base64 có phải là encryption không? Bảo mật của Secret đến từ đâu?
2. Khi nào dùng volume mount thay vì env vars?
3. Tại sao không bao giờ commit Secret YAML vào Git?

---

**Tiếp theo:** [05_service.md](./05_service.md) — Service giải quyết vấn đề IP thay đổi của Pod.
