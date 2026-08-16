# Keycloak — Identity Provider (GĐ2)

Keycloak chạy **dev mode** (`start-dev`) trong namespace `iam`, tách khỏi
namespace `crm` chứa app. Đây **không phải cấu hình production** — không
TLS, DB là H2 in-memory/ephemeral (mất dữ liệu khi pod bị recreate), admin
credential đơn giản. Chỉ dùng cho lab demo ZTNA.

Realm `crm` được định nghĩa hoàn toàn bằng file khai báo
[`realm-export.json`](./realm-export.json) — infrastructure-as-code, không
cấu hình tay qua UI. File này được `kustomize` (`configMapGenerator`) đóng
gói thành ConfigMap và Keycloak import lúc khởi động qua cờ
`--import-realm` (mount vào `/opt/keycloak/data/import`).

## Deploy

```
kubectl apply -k infra/keycloak/
```

## Nội dung realm `crm`

- 3 realm role: `guest`, `staff`, `admin`
- 3 user, mỗi user gán đúng 1 role:

  | Username | Password | Role |
  |---|---|---|
  | `guest-user` | `GuestPass123!` | `guest` |
  | `staff-user` | `StaffPass123!` | `staff` |
  | `admin-user` | `AdminPass123!` | `admin` |

  > ⚠️ Đây là **credential thử nghiệm cho lab**, hardcode trong file khai
  > báo để tái tạo được từ đầu. Không dùng ngoài môi trường lab này.

- Client `admin-cli` được bật `directAccessGrantsEnabled` để test lấy
  token bằng Direct Access Grant (password grant) mà không cần thêm
  client mới — client Pomerium (nếu cần) sẽ được thêm ở GĐ4.

## Địa chỉ

- Trong cluster (dùng cho Pomerium ở GĐ4): `http://keycloak.iam.svc.cluster.local:8080`
- Admin console (user `admin` / `admin`, lab-only): port-forward rồi vào `http://localhost:8080`

## Port-forward để test tay

```
kubectl -n iam port-forward svc/keycloak 8080:8080
```

Sau đó lấy token bằng Direct Access Grant, ví dụ cho `guest-user`:

```
curl -s -X POST http://127.0.0.1:8080/realms/crm/protocol/openid-connect/token \
  -d "client_id=admin-cli" \
  -d "grant_type=password" \
  -d "username=guest-user" \
  -d "password=GuestPass123!"
```

Decode phần payload của `access_token` (base64url, không cần tool ngoài):

```
python -c "import sys,json,base64; p='<access_token>'.split('.')[1]; p+='='*(-len(p)%4); print(json.dumps(json.loads(base64.urlsafe_b64decode(p)), indent=2))"
```

Kiểm tra `realm_access.roles` chứa đúng role kỳ vọng của user.
