# Pomerium — ZTNA Gateway North-South (GĐ4)

Pomerium deploy trong namespace `gateway`, tách khỏi `crm` (app) và `iam`
(Keycloak). Chỉ 1 route ở giai đoạn này: `/admin` → `admin-service`, chỉ
role `admin` (theo `realm_access.roles` từ Keycloak) mới ALLOW.

## Vì sao có 2 Service cùng trỏ 1 pod

Pomerium bắt buộc `authenticate_service_url` (nơi xử lý OIDC
redirect/callback) phải khác domain với domain của route ứng dụng. Do đó
có 2 Service K8s, cùng selector `app: pomerium`, chỉ khác tên (khác DNS):

- `pomerium.gateway.svc.cluster.local` — dùng làm `authenticate_service_url`
- `admin.gateway.svc.cluster.local` — dùng làm `from` của route `/admin`

## LAB-ONLY

- TLS dùng cert self-signed (`tls-lab-only/`, SAN cho cả 2 hostname trên,
  10 năm) — Pomerium (bản mới) không cho route chạy HTTP thuần, nên phải
  bật TLS thật kể cả trong lab. Không dùng cert này ngoài môi trường lab.
- `secret.yaml` chứa `IDP_CLIENT_SECRET`/`COOKIE_SECRET`/`SHARED_SECRET`
  hardcode sẵn để reproducible qua git — không dùng production.

## Deploy

```
kubectl apply -k infra/keycloak/   # client "pomerium" phải tồn tại trước
kubectl apply -k infra/pomerium/
```

## Vấn đề đã gặp khi verify (đáng lưu ý cho các giai đoạn sau)

Mapper mặc định "realm roles" của Keycloak (trên client scope `roles`)
chỉ add `realm_access.roles` vào **access token**
(`access.token.claim: true`), KHÔNG add vào **ID token** hay
**userinfo** theo mặc định. Pomerium (OIDC Authorization Code flow, dùng
ID token/userinfo để build claims) vì vậy không thấy claim này — mọi
user, kể cả admin-user, đều bị `claim-unauthorized`. Test password-grant
trực tiếp ở GĐ2 không phát hiện ra vì test đó decode access token, không
đi qua Authorization Code flow.

Fix: thêm 1 protocol mapper riêng ở **client `pomerium`** (không sửa
mapper mặc định toàn realm, tránh ảnh hưởng client khác) với
`id.token.claim: true` và `userinfo.token.claim: true` — xem
`infra/keycloak/realm-export.json`, mapper `realm-roles-in-id-token`.

## Cách test tay (automate OIDC Authorization Code flow bằng curl)

Không cần trình duyệt. Từ 1 pod debug (`curlimages/curl`) trong cùng
cluster (ví dụ namespace `gateway`), dùng chung 1 cookie jar qua các bước:

```
# 1. Kích hoạt redirect chain, lấy trang login Keycloak thật
curl -sk -c cookies.txt -L https://admin.gateway.svc.cluster.local:8080/admin > login.html

# 2. Parse action="..." của <form> trong login.html (URL login-actions/authenticate
#    kèm session_code/execution/tab_id) — regex, không cần lib ngoài

# 3. Submit credential thật, follow tiếp redirect (Keycloak -> Pomerium
#    oauth2/callback -> Pomerium set session -> route /admin)
curl -sk -i -b cookies.txt -c cookies.txt -L \
  --data-urlencode "username=admin-user" \
  --data-urlencode "password=AdminPass123!" \
  --data-urlencode "credentialId=" \
  "<login_url_from_step_2>"
```

Response cuối cùng là response thật của route `/admin` sau khi đã đi qua
toàn bộ OIDC flow + policy evaluation của Pomerium. Đối chiếu thêm bằng
log `kubectl -n gateway logs deploy/pomerium` (dòng
`"message":"authorize check"` có `email`, `allow`, `allow-why-true` /
`allow-why-false`) — nguồn bằng chứng độc lập với response HTTP.

Chi tiết đầy đủ 3 test (admin/guest/staff) xem `docs/evidence/gd4-after/`.

## Cập nhật GĐ5 — Pomerium tham gia Istio mesh

Sau khi GĐ5 áp PeerAuthentication STRICT cho namespace `crm`, Pomerium
(gọi `admin-service.crm.svc.cluster.local` bằng plaintext HTTP) không
còn kết nối được nếu đứng ngoài mesh. Đã xử lý:

- ServiceAccount riêng `pomerium` (thay vì `default`) trong namespace
  `gateway` — cho identity mTLS `cluster.local/ns/gateway/sa/pomerium`.
- Namespace `gateway` bật `istio-injection=enabled` — Pomerium có sidecar.
- Port 8080 (nơi Pomerium tự terminate TLS bằng cert riêng) đổi tên
  thành `https` (thay vì `http`) VÀ loại khỏi INBOUND interception qua
  annotation `traffic.sidecar.istio.io/excludeInboundPorts: "8080"` —
  biên TLS North-South (Pomerium tự terminate cho user/browser bên
  ngoài) tách biệt khỏi mTLS East-West nội bộ mesh. OUTBOUND (Pomerium ->
  admin-service) vẫn qua sidecar để tự động mTLS.
- 1 AuthorizationPolicy bổ sung (`allow-pomerium-ingress-to-admin`,
  `infra/istio/authorization-policies.yaml`) cho phép đúng principal
  `cluster.local/ns/gateway/sa/pomerium` gọi `/admin` — vì
  `restrict-admin-service` (rules: []) chặn tuyệt đối, kể cả Pomerium,
  nếu không có policy riêng này.

Lý do đầy đủ + quá trình debug: xem `docs/NOTES.md`. Deploy qua kustomize
như cũ:

```
kubectl apply -k infra/pomerium/
```

(Lưu ý: đừng dùng `kubectl apply -f infra/pomerium/deployment.yaml` trực
tiếp — file này không tự khai báo `namespace: gateway`, dựa vào
kustomize để inject namespace + tạo ConfigMap/Secret có hash suffix từ
`config.yaml`/`tls-lab-only/`. Áp trực tiếp bằng `-f` sẽ tạo nhầm tài
nguyên trong namespace `default` và không cập nhật được bản đang chạy.)
