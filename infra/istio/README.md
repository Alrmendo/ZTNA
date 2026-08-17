# Istio — mTLS + AuthorizationPolicy East-West (GĐ5)

## Cài đặt

Dùng `istioctl` (không có sẵn trong PATH — tải bản 1.28.10, bản mới nhất
còn tương thích chính thức với Kubernetes 1.30.0 của cluster Kind hiện
có; xem lý do chọn version ở `docs/NOTES.md`):

```
istioctl install --set profile=demo -y
```

`profile=demo` là profile khuyến nghị cho lab/getting-started của chính
Istio — đủ istiod + ingress/egress gateway mẫu, không phải cấu hình
production.

## Bật sidecar injection cho namespace `crm`

```
kubectl label namespace crm istio-injection=enabled --overwrite
kubectl rollout restart deployment user-service order-service admin-service -n crm
```

## Áp policy (thứ tự đúng nguyên tắc xác minh mục 9 PLAN.md)

```
istioctl analyze -n crm
kubectl apply -f infra/istio/peer-authentication.yaml
istioctl analyze -n crm
kubectl apply -f infra/istio/authorization-policies.yaml
istioctl analyze -n crm
```

`authorization-policies.yaml` chứa 3 policy:
1. `allow-user-to-order` — nguyên văn PLAN.md mục 4 (đã sửa path, xem NOTES.md).
2. `restrict-admin-service` — nguyên văn PLAN.md mục 4 (deny-all, không sửa).
3. `allow-pomerium-ingress-to-admin` — bổ sung ở GĐ5 bước 5, xem `docs/NOTES.md`
   để biết đầy đủ lý do (regression fix cho Scenario A, không phải mở rộng scope).

## Pomerium tham gia mesh

Xem `infra/pomerium/README.md` (mục cập nhật GĐ5) + `docs/NOTES.md` — cần
thiết để Pomerium có identity mTLS gọi được `admin-service` sau khi
PeerAuthentication STRICT được áp.
