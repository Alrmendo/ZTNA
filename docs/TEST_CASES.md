# Test Cases — ZTNA Lab Demo

> Trích từ mục 4 (Attack Scenarios) + mục 5 (Expected Evidence) của [PLAN.md](./PLAN.md), viết lại dưới dạng checklist để tick khi test thật. Nếu có sai khác với PLAN.md, PLAN.md là nguồn sự thật.

## Ý nghĩa chính xác của "BEFORE"

> BEFORE nghĩa là trạng thái **thật sự chưa có Pomerium/Istio đứng giữa request** — không phải đã deploy công cụ nhưng để policy mở.
> - **Scenario A:** BEFORE phải test bằng cách truy cập trực tiếp vào app (ví dụ port-forward hoặc gọi thẳng ClusterIP/NodePort của service), **trước khi Pomerium được deploy**. Chỉ sau khi có bằng chứng ALLOWED ở bước này mới deploy Pomerium và test lại (AFTER).
> - **Scenario B:** BEFORE phải test `user-service → admin-service` **trước khi cài Istio / trước khi AuthorizationPolicy + mTLS strict được áp**. Chỉ sau khi có bằng chứng ALLOWED ở bước này mới deploy Istio + policy và test lại (AFTER).
>
> Thứ tự giai đoạn (GĐ3 chạy trước GĐ4 và GĐ5) phải được tuân thủ — không vô tình cài Pomerium/Istio sớm hơn rồi nhầm đó là "before".

---

## Scenario A — North-South *(attack vector: Identity compromise — Vector 1)*

### BEFORE — chưa deploy Pomerium (test qua GĐ3)

> Vì Pomerium chưa tồn tại, không có cơ chế nào gắn identity vào request — gọi thẳng
> `/admin` không kèm token nào đại diện đúng cho cả 3 actor (Guest/Staff/Admin), vì
> không ai bị phân biệt ở trạng thái này. Cả 3 dòng dùng chung 1 evidence file.

- [x] Guest → `/admin` → kỳ vọng **ALLOWED (~200)** — thực tế: **200 ALLOWED** — evidence: [gd3-before/scenario-a-direct-admin.txt](./evidence/gd3-before/scenario-a-direct-admin.txt)
- [x] Staff → `/admin` → kỳ vọng **ALLOWED (~200)** — thực tế: **200 ALLOWED** — evidence: [gd3-before/scenario-a-direct-admin.txt](./evidence/gd3-before/scenario-a-direct-admin.txt)
- [x] Admin → `/admin` → kỳ vọng **ALLOWED (~200)** — thực tế: **200 ALLOWED** — evidence: [gd3-before/scenario-a-direct-admin.txt](./evidence/gd3-before/scenario-a-direct-admin.txt)

### AFTER — Pomerium identity-aware access control (test qua GĐ4)

- [ ] Guest → `/admin` → kỳ vọng **DENIED (~403)** — evidence: HTTP response + Pomerium log
- [ ] Staff → `/admin` → kỳ vọng **DENIED (~403)** — evidence: HTTP response + Pomerium log
- [ ] Admin → `/admin` → kỳ vọng **ALLOWED (~200)** — evidence: HTTP response

---

## Scenario B — East-West *(attack vector: Workload compromise — Vector 2)*

### BEFORE — chưa cài Istio/AuthorizationPolicy (test qua GĐ3)

- [x] `user-service` → `order-service` → kỳ vọng **ALLOWED (~200)** — đúng phạm vi nghiệp vụ — thực tế: **200 ALLOWED** — evidence: [gd3-before/scenario-b-user-to-order.txt](./evidence/gd3-before/scenario-b-user-to-order.txt)
- [x] `user-service` → `admin-service` → kỳ vọng **ALLOWED (~200)** — lateral movement thành công (vấn đề cần khắc phục) — thực tế: **200 ALLOWED** — evidence: [gd3-before/scenario-b-user-to-admin.txt](./evidence/gd3-before/scenario-b-user-to-admin.txt)

### AFTER — Istio mTLS + AuthorizationPolicy (test qua GĐ5)

- [ ] `user-service` → `order-service` → kỳ vọng **ALLOWED (~200)** — vẫn trong phạm vi least-privilege — evidence: Service log
- [ ] `user-service` → `admin-service` → kỳ vọng **DENIED (~403)** — chặn bởi AuthorizationPolicy — evidence: Istio policy log

---

## Ghi chú

> Mã HTTP (200/403) là **giá trị kỳ vọng**, không phải invariant tuyệt đối — mã thực tế có thể khác tùy cấu hình. Điều cần chứng minh là **ALLOWED → DENIED**, không phải đúng con số status code.

> `rules: []` trên `restrict-admin-service` chỉ có ý nghĩa deny-all nếu Istio thực sự evaluate đúng như kỳ vọng — đừng chỉ tin vào YAML vì nó trông hợp lý. Áp dụng nguyên tắc xác minh ở mục 9 PLAN.md (write policy → istioctl analyze / kiểm tra tương đương → deploy → test ALLOW-case → test DENY-case) trước khi đánh dấu GĐ4 hoặc GĐ5 hoàn thành.
