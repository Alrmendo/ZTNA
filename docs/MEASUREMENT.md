# MEASUREMENT — GĐ6: Đo lường & so sánh Before/After

> Nguồn sự thật cho project vẫn là [PLAN.md](./PLAN.md). File này bổ sung
> số liệu định lượng cho tiêu chí thành công ở PLAN.md mục 7 ("Độ trễ do
> Pomerium/Istio gây ra nằm trong ngưỡng chấp nhận được").

## Vì sao không tái tạo "before" trong namespace `crm`

Sau GĐ4/GĐ5, `crm` đã có Pomerium (North-South) và Istio mTLS STRICT +
AuthorizationPolicy (East-West) đứng giữa mọi request thật — đây chính
là lab bảo mật đang được chứng minh, tắt/gỡ chúng để "đo lại before" sẽ
phá huỷ trạng thái đó. Thay vào đó, GĐ6 dùng 1 namespace đo lường riêng,
tạm thời — `perf-baseline` — KHÔNG bật `istio-injection`, KHÔNG có
Pomerium đứng trước, chạy đúng image `:local` y hệt `order-service` và
`admin-service` thật. Đây chỉ là công cụ đo (điểm tham chiếu "raw
latency", tương đương chi phí xử lý thuần của service, không qua bất kỳ
lớp security nào — giống bản chất trạng thái GĐ3), không phải một phần
kiến trúc lab, và đã bị xoá sạch ngay sau khi lấy đủ dữ liệu (bước 7).

**Lưu ý về phương pháp so sánh:** baseline raw là gọi thẳng 1-hop tới
bản sao service trong `perf-baseline`; "after" là đường đi THẬT đang
chạy — với East-West đi qua `user-service` (endpoint `/simulate/call-order`,
2-hop, có mTLS STRICT + AuthorizationPolicy ở hop thứ 2), với North-South
đi qua Pomerium (OIDC-authenticated route, TLS + policy evaluation).
Overhead đo được vì vậy phản ánh **chi phí đường đi thật so với chi phí
xử lý thuần** (bao gồm cả hop bổ sung của kiến trúc, không tách riêng
tuyệt đối "chỉ chi phí mTLS/policy") — đúng với câu hỏi thực tế mà lab
muốn trả lời: "dùng hệ thống ZTNA thật tốn thêm bao nhiêu so với không
có security". Client đo (a) và (b) dùng CHUNG 1 pod (`perf-client` trong
`crm`, có sidecar) để triệt tiêu chênh lệch do bản thân sidecar của
client gây ra khi so sánh; tương tự (c) và (d) dùng chung 1 pod
(`perf-client` trong `gateway`, KHÔNG sidecar — đại diện đúng bản chất
một client bên ngoài mesh, ví dụ trình duyệt thật).

## Phương pháp

- Script: [`infra/perf/measure-latency.sh`](../infra/perf/measure-latency.sh)
  (bash + curl, N=50 request tuần tự/target, in `%{time_total}` từng
  dòng) chạy TRONG pod debug qua `kubectl exec` (không đo từ host, tránh
  cộng dồn overhead của bản thân `kubectl exec` vào từng phép đo).
- Tổng hợp mean/median/p95: [`infra/perf/aggregate.py`](../infra/perf/aggregate.py).
- Session Pomerium tái sử dụng: [`infra/perf/oidc-login.sh`](../infra/perf/oidc-login.sh)
  (login OIDC 1 lần, lấy cookie jar, N=50 request sau đó tái dùng cookie
  — không tính chi phí OIDC login flow vào con số latency vì đó là chi
  phí one-time không lặp lại mỗi request thật).
- Consistency check: [`infra/perf/check-status.sh`](../infra/perf/check-status.sh)
  (N=20 request, in mã HTTP từng dòng).
- Dữ liệu thô: `docs/evidence/gd6-measurement/`.

## 1. Bảng latency overhead (ms)

| Target | N | Mean | Median | p95 | Min | Max |
|---|---|---|---|---|---|---|
| (a) RAW — perf-client(crm) → `perf-baseline/order-service` | 50 | 2.96 | 2.83 | 3.83 | 2.35 | 6.29 |
| (b) AFTER East-West — perf-client(crm) → `user-service`/simulate/call-order → `order-service` | 50 | 6.00 | 5.70 | 7.90 | 4.84 | 15.49 |
| (c) RAW — perf-client(gateway) → `perf-baseline/admin-service` | 50 | 2.02 | 1.96 | 2.39 | 1.78 | 2.84 |
| (d) AFTER North-South — perf-client(gateway) → Pomerium (session admin-user tái sử dụng) → `admin-service` | 50 | 12.02 | 11.53 | 14.28 | 10.45 | 24.48 |

Dữ liệu thô: `docs/evidence/gd6-measurement/raw-{a,b,c,d}-*.txt`,
tổng hợp CSV: `docs/evidence/gd6-measurement/results.csv`.

### Overhead

| So sánh | Mean | Median | p95 |
|---|---|---|---|
| **East-West** (b − a) | +3.04 ms (+102.7%) | +2.87 ms (+101.4%) | +4.07 ms (+106.3%) |
| **North-South** (d − c) | +10.00 ms (+495.0%) | +9.57 ms (+488.3%) | +11.89 ms (+497.5%) |

**Nhận xét:** overhead % của North-South trông rất cao vì baseline (c)
vốn đã cực nhanh (gọi thẳng service nội bộ, không TLS) — số tuyệt đối
mới là con số có ý nghĩa cho câu hỏi "chấp nhận được không" ở PLAN.md
mục 7. Cả 2 trường hợp overhead tuyệt đối đều dưới **15ms** (mean), nằm
trong ngưỡng hoàn toàn chấp nhận được cho một ứng dụng nội bộ (không
phải hệ thống real-time/latency-critical). Overhead North-South cao hơn
East-West vì bao gồm thêm: TLS handshake thật (không phải mTLS
tái sử dụng connection), route policy evaluation của Pomerium, và
thêm 1 hop (Pomerium → admin-service) so với baseline 1-hop.

## 2. Consistency check (DENY-case, N=20/case)

| Test | Kỳ vọng | Kết quả | Evidence |
|---|---|---|---|
| `guest-user` → `/admin` (qua Pomerium, session tái sử dụng) | 20/20 DENIED (403) | **20/20 DENIED** | [gd6-measurement/consistency-guest-admin.txt](./evidence/gd6-measurement/consistency-guest-admin.txt) |
| `staff-user` → `/admin` (qua Pomerium, session tái sử dụng) | 20/20 DENIED (403) | **20/20 DENIED** | [gd6-measurement/consistency-staff-admin.txt](./evidence/gd6-measurement/consistency-staff-admin.txt) |
| `user-service` → `admin-service` (Istio RBAC) | 20/20 DENIED (403) | **20/20 DENIED** | [gd6-measurement/consistency-eastwest-admin.txt](./evidence/gd6-measurement/consistency-eastwest-admin.txt) |

**Không có lần nào lọt qua (0 leak / 60 request DENY-case).** Cả 3 policy
(Pomerium role-based cho guest/staff, Istio AuthorizationPolicy cho
East-West) hoạt động nhất quán 100% qua nhiều lần gọi lặp lại, không chỉ
đúng ở lần test đầu tiên (GĐ4/GĐ5).

## 3. Coverage log

Đối chiếu số request THẬT đã gửi (đếm bằng script) với số dòng log ghi
nhận được ở Pomerium (`kubectl logs -n gateway deploy/pomerium`) và
Istio/Envoy sidecar (`kubectl logs -n crm deploy/<svc> -c istio-proxy`),
cùng khung thời gian test:

| Nguồn log | Request thật đã gửi (khớp chính xác) | Dòng log tìm thấy | Coverage |
|---|---|---|---|
| Pomerium — `authorize check`, `path=/admin` (bước 2d + bước 4 guest/staff + các lần login/sanity-check kèm theo) | 99 (52 admin-user + 22 guest-user + 22 staff-user + 3 request chưa xác thực trước khi redirect login) | 99 | **100%** |
| Istio/Envoy `order-service` — `GET /api/orders` (bước 2b + 1 sanity-check) | 51 | 51 | **100%** |
| Istio/Envoy `admin-service` — `GET /admin` (bước 2d qua Pomerium: 52 mã 200 + bước 4 East-West: 20 mã 403) | 72 | 72 | **100%** |

**Tổng security-relevant request đối chiếu được: 222/222 dòng log — coverage 100%.**
Không có request nào đi qua Pomerium hoặc Istio mà thiếu log — đúng tiêu
chí "100% security-relevant request được ghi nhận" ở PLAN.md mục 7 (vế
Graylog của tiêu chí này chỉ áp dụng nếu làm GĐ7; log vẫn đầy đủ ở nguồn
dù chưa tập trung hoá).

Log thô: `docs/evidence/gd6-measurement/pomerium-authz-logs.txt`.

## 4. Đối chiếu tiêu chí thành công (PLAN.md mục 7)

| Tiêu chí | Kết quả GĐ6 |
|---|---|
| Chứng minh trực quan cả 2 scenario theo Expected Evidence | Đã có ở GĐ4/GĐ5 (`docs/evidence/gd4-after/`, `gd5-after/`); GĐ6 bổ sung consistency 20/20 — không phải may mắn 1 lần | 
| Latency overhead nằm trong ngưỡng chấp nhận được | Mean overhead: East-West +3.04ms, North-South +10.00ms — chấp nhận được cho ứng dụng nội bộ |
| 100% security-relevant request được log | Xác nhận 100% (222/222) ở nguồn Pomerium + Istio; Graylog (GĐ7) không bắt buộc |
| Tài liệu trình bày BEFORE → AFTER North-South → BEFORE → AFTER East-West kèm số liệu | `docs/evidence/` (GĐ3/4/5) + file này (GĐ6) — đủ dữ liệu cho GĐ8 |

## Dọn dẹp

Namespace `perf-baseline`, pod `perf-client` (namespace `crm` và
`gateway`), cookie jar tạm và session guest/staff/admin-user dùng riêng
cho đo lường đã bị xoá sạch sau khi lấy đủ dữ liệu — không để lại tài
nguyên thừa trong `crm`/`gateway`/`istio-system`.
