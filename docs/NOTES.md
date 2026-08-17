# NOTES — sai khác so với thiết kế ban đầu (PLAN.md)

> File này ghi lại các điều chỉnh phát sinh trong lúc triển khai mà
> PLAN.md gốc chưa lường hết, để phần báo cáo (GĐ8) phản ánh đúng thực tế
> đã làm. Không thay đổi kiến trúc/mục tiêu — chỉ là chi tiết vận hành
> cần thiết để PLAN.md hoạt động đúng như ý định.

## GĐ5 — bước 5: Pomerium tham gia Istio mesh + AuthorizationPolicy bổ sung

### Vấn đề

PLAN.md mục 4 định nghĩa `restrict-admin-service` với `action: ALLOW,
rules: []` — đúng nghĩa deny-all cho **mọi** traffic tới admin-service ở
tầng Istio, không phân biệt được nguồn. Nhưng kiến trúc mục 2 lại quy
định admin-service "chỉ được truy cập qua Pomerium ở tầng North-South" —
tức Pomerium PHẢI vẫn gọi được `admin-service.crm.svc.cluster.local`.
Hai điều này mâu thuẫn nhau theo đúng nghĩa đen của YAML: một khi
PeerAuthentication STRICT + restrict-admin-service được áp, Pomerium
(đứng ngoài mesh, gọi plaintext HTTP) sẽ bị chặn giống hệt user-service —
phá vỡ Scenario A đã PASS ở GĐ4. Đây là rủi ro đã được nêu trước trong
yêu cầu triển khai GĐ5 (bước 5), không phải phát hiện tình cờ.

### Đã thử / đã làm — theo đúng gợi ý ở yêu cầu triển khai GĐ5 bước 5

1. **Đưa Pomerium vào mesh** để nó có identity mTLS thật, thay vì né
   tránh bằng cách để mTLS PERMISSIVE hoặc bỏ STRICT (điều PLAN.md cấm
   rõ — mục 4 bắt buộc dùng STRICT):
   - Thêm `ServiceAccount pomerium` riêng trong `infra/pomerium/deployment.yaml`
     (trước đó Pomerium dùng SA `default` của namespace `gateway`, giống
     tình trạng 3 service `crm` trước GĐ5 bước 0).
   - Label `istio-injection=enabled` cho namespace `gateway`, rollout
     restart — Pomerium giờ có sidecar, identity
     `cluster.local/ns/gateway/sa/pomerium`.

2. **Sự cố phát sinh sau khi có sidecar**: Pomerium tự terminate TLS trên
   port 8080 bằng cert riêng (`tls-lab-only/`) — nhưng port đó lại được
   đặt tên `http` trong Service/containerPort. Istio dùng tên port để
   suy ra protocol; đặt tên `http` khiến Envoy cố parse byte TLS thô như
   HTTP thuần, dẫn tới `filter_chain_not_found` / reset kết nối ngay cả
   với client hợp lệ (external user, chưa nói tới Pomerium gọi
   admin-service). Khắc phục 2 phần:
   - Đổi tên port thành `https` (Service + containerPort) trong
     `infra/pomerium/deployment.yaml`.
   - Thêm annotation `traffic.sidecar.istio.io/excludeInboundPorts:
     "8080"` trên pod Pomerium — loại port 8080 khỏi INBOUND interception
     của sidecar. Lý do: cổng này là biên TLS **North-South** (Pomerium
     tự terminate, phục vụ user/browser bên ngoài), khác bản chất với
     mTLS **East-West** nội bộ mesh mà GĐ5 đang muốn enforce. Sidecar vẫn
     bắt bình thường traffic OUTBOUND (Pomerium -> admin-service) để tự
     động mTLS — đây mới là phần cần Pomerium "ở trong mesh".

3. **AuthorizationPolicy bổ sung** (`infra/istio/authorization-policies.yaml`,
   policy thứ 3, ngoài 2 policy PLAN.md yêu cầu):

   ```yaml
   apiVersion: security.istio.io/v1
   kind: AuthorizationPolicy
   metadata:
     name: allow-pomerium-ingress-to-admin
     namespace: crm
   spec:
     selector:
       matchLabels:
         app: admin-service
     action: ALLOW
     rules:
       - from:
           - source:
               principals: ["cluster.local/ns/gateway/sa/pomerium"]
         to:
           - operation:
               paths: ["/admin"]
   ```

   **Vì sao đây KHÔNG phải "nới lỏng rules: [] thành cho phép tất cả"**
   (điều yêu cầu triển khai GĐ5 bước 5 cấm rõ): `restrict-admin-service`
   giữ NGUYÊN VĂN như PLAN.md — không sửa, không thêm rule, vẫn deny-all
   tuyệt đối, vẫn chặn `user-service -> admin-service` (xác nhận bằng
   test DENY-case, xem `docs/evidence/gd5-after/scenario-b-user-to-admin-deny.txt`).
   Istio OR nhiều AuthorizationPolicy ALLOW cho cùng 1 selector với nhau
   — `allow-pomerium-ingress-to-admin` là một lối đi RIÊNG, least-
   privilege (đúng 1 principal, đúng 1 path), phản ánh đúng vai trò ZTNA
   gateway của Pomerium (một lớp biên North-South tách biệt), không phải
   một service ngang hàng trong `crm`. `restrict-admin-service` vẫn giữ
   đúng ý nghĩa "deny-all cho service-to-service" mà nó được thiết kế để
   chứng minh.

### Kết quả

Regression check Scenario A (admin-user -> /admin) sau GĐ5: **PASS**
(200 ALLOWED, xác nhận độc lập bằng cả Pomerium log lẫn Envoy/Istio log
của admin-service — xem `docs/evidence/gd5-after/scenario-a-admin-regression-check.txt`).

---

## GĐ5 — bước 4: sửa path trong `allow-user-to-order`

PLAN.md mục 4 ghi `paths: ["/api/orders/*"]` cho policy
`allow-user-to-order`. Route thật của `order-service`
(`services/order-service/index.js`) là đúng `/api/orders` (không có dấu
`/` theo sau, không có sub-resource). `"/api/orders/*"` là prefix-match
yêu cầu literal `/api/orders/` — không khớp `/api/orders` (thiếu dấu
`/`). Áp policy nguyên văn khiến chính traffic HỢP LỆ
(user-service -> order-service) bị 403 — phát hiện đúng lúc chạy test
ALLOW-case theo nguyên tắc xác minh mục 9 PLAN.md.

Khắc phục: sửa thành `paths: ["/api/orders", "/api/orders/*"]` (thêm
exact-match, giữ nguyên prefix-match cho sub-path nếu sau này có). Chi
tiết + evidence: `docs/evidence/gd5-after/scenario-b-user-to-order-allow.txt`.

---

## GĐ5 — bước 1: chọn phiên bản Istio

PLAN.md mục 6 yêu cầu "bản ổn định mới nhất". Bản mới nhất tại thời điểm
triển khai (2026-08-17) là Istio 1.30.3, nhưng 1.30.3 yêu cầu tối thiểu
Kubernetes 1.32 — cluster Kind hiện tại (dựng ở GĐ1) chạy Kubernetes
1.30.0, thấp hơn ngưỡng hỗ trợ. Cài 1.30.3 lên cluster không tương thích
là rủi ro thực chất (không chỉ cảnh báo suông), có thể gây lỗi khó chẩn
đoán ở các bước sau. Chọn Istio **1.28.10** (bản patch mới nhất của
nhánh 1.28) — bản mới nhất còn tương thích chính thức với Kubernetes
1.30.0 của cluster hiện có (chỉ có cảnh báo nhánh 1.28 đã EOL upstream,
không có cảnh báo không tương thích Kubernetes). Đánh đổi hợp lý cho một
lab cố định phiên bản cluster, ưu tiên "chạy đúng" hơn "mới nhất tuyệt
đối".

---

## GĐ5 — bước 4: đặt tên port cho 3 Service trong `crm`

Thêm `name: http` cho port trong `infra/k8s/{user,order,admin}-service.yaml`
(trước đó port không tên). Không có tên port khiến `istioctl analyze`
báo Info `IST0118` (port naming convention) và khiến Istio phải dò
protocol thay vì biết chắc là HTTP — rủi ro với AuthorizationPolicy dùng
path-matching (L7) như `allow-user-to-order`. Đây là thay đổi nhỏ, không
ảnh hưởng hành vi ứng dụng, chỉ để đảm bảo Istio nhận diện đúng protocol
cho L7 policy.
