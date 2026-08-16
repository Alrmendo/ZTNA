# KẾ HOẠCH TRIỂN KHAI PROJECT — v5 (Sẵn sàng triển khai)

## Zero Trust Network Access (ZTNA) — Lab Demo Kỹ Thuật

*Đã qua 4 vòng đánh giá độc lập: v1 → 8/10, v2 → 9/10, v3 → 9.3/10, v4 → 9.5/10*

> **Trạng thái:** kiến trúc đã chốt — bên đánh giá xác nhận **không cần sửa architecture nữa**. v5 chỉ bổ sung 2 nguyên tắc vận hành để đảm bảo evidence thu được khi triển khai là đáng tin cậy. Từ đây, giá trị project nằm ở **triển khai đúng và thu evidence chuẩn**, không nằm ở việc mở rộng kiến trúc.

---

## Những thay đổi so với v4

- Thêm **nguyên tắc xác minh** trước khi đánh dấu một giai đoạn triển khai (GĐ4, GĐ5) là hoàn thành — không tin YAML chỉ vì nó "trông hợp lý".
- Làm rõ **ý nghĩa chính xác của "BEFORE"**: phải là trạng thái thật sự chưa có Pomerium/Istio đứng giữa, không phải đã deploy nhưng để policy mở.

---

## 1. Tổng quan

**Mục tiêu:** xây dựng một security experiment có hypothesis, baseline, controlled attack, mitigation và measurable result — minh họa kiến trúc Zero Trust bằng thực nghiệm, không chỉ trình bày lý thuyết.

**Phạm vi:** lab trên Kubernetes (Kind/Minikube local, có thể mở rộng GKE), mô phỏng 3 service kiểu CRM (`user-service`, `order-service`, `admin-service`), kiểm thử 2 lớp bảo mật riêng biệt: truy cập người dùng vào ứng dụng (North-South) và giao tiếp giữa các service nội bộ (East-West).

---

## 2. Kiến trúc theo lớp

```
                ┌───────────┐
                │ Keycloak  │   Identity
                └─────┬─────┘
                      │ OIDC
                      ▼
User ───────────► Pomerium         North-South
                      │             (Access Control)
                      ▼
              ┌───────────────┐
              │  CRM Services │
              │ user / order /│
              │     admin     │
              └───────┬───────┘
                      │
                      ▼
             Istio mTLS +               East-West
           AuthorizationPolicy        (Workload Security)
```

| Thành phần | Loại | Vai trò trong kiến trúc | Lưu ý khi trình bày |
|---|---|---|---|
| Keycloak | Identity Provider | Xác thực người dùng qua OIDC, cấp identity cho toàn hệ thống. | Không phải ZTNA — là nền tảng identity mà ZTNA dựa vào. |
| Pomerium | ZTNA access proxy | Kiểm soát truy cập người dùng vào ứng dụng theo identity/role (North-South). | Đây là thành phần triển khai ZTNA chính ở tầng người dùng. |
| Istio | Zero-trust workload security | mTLS + least-privilege AuthorizationPolicy giữa các service (East-West). | Bổ trợ theo cùng nguyên lý "never trust, always verify", không phải bản thân ZTNA. |
| Graylog | Observability / audit | Tập trung log để hỗ trợ giám sát liên tục. | Không phải cơ chế enforcement — chỉ hỗ trợ continuous monitoring. |

---

## 3. Threat Model

Project thực nghiệm **2 attack vector riêng biệt**, mỗi vector ứng với đúng một scenario.

### Vector 1 — Identity compromise (dùng cho Scenario A / North-South)
- Attacker có được credential hợp lệ của một user thông thường (ví dụ qua phishing/leak).
- Attacker **chưa** chiếm được bất kỳ workload nào trong cluster.
- Câu hỏi kiểm chứng: một identity hợp lệ nhưng sai role có truy cập được route ngoài phạm vi của mình không?

### Vector 2 — Workload compromise (dùng cho Scenario B / East-West)
- Attacker khai thác lỗ hổng ứng dụng giả lập để chiếm được `user-service` (không phải qua credential riêng lẻ).
- Attacker có quyền thực thi trong ngữ cảnh của `user-service`, tức gọi được các service khác bằng chính identity/service account của `user-service`.
- Câu hỏi kiểm chứng: một workload bị compromise có di chuyển ngang được sang service ngoài phạm vi cần thiết không?

**Giả định chung cho cả 2 vector:** không có quyền truy cập Kubernetes control-plane; không có cluster-admin; không thể chỉnh sửa policy đã cấu hình.

**Tài sản cần bảo vệ (assets):** `admin-service` và dữ liệu quản trị; dữ liệu user, dữ liệu order; Identity Provider (Keycloak).

**Security objective:**
> Có identity hợp lệ không đồng nghĩa có toàn quyền truy cập (**valid identity ≠ unlimited access**).
> Một workload bị compromise không đồng nghĩa toàn cluster bị compromise (**compromised workload ≠ cluster-wide access**).

---

## 4. Kịch bản kiểm thử (Attack Scenarios)

> ⚠️ **Ý nghĩa chính xác của "BEFORE"** (điểm cần lưu ý khi implement): BEFORE nghĩa là trạng thái **thật sự chưa có Pomerium/Istio đứng giữa request** — không phải đã deploy công cụ nhưng để policy mở. Cụ thể:
> - **Scenario A:** BEFORE phải test bằng cách truy cập trực tiếp vào app (ví dụ port-forward hoặc gọi thẳng ClusterIP/NodePort của service), **trước khi Pomerium được deploy**. Chỉ sau khi có bằng chứng ALLOWED ở bước này mới deploy Pomerium và test lại (AFTER).
> - **Scenario B:** BEFORE phải test `user-service → admin-service` **trước khi cài Istio / trước khi AuthorizationPolicy + mTLS strict được áp**. Chỉ sau khi có bằng chứng ALLOWED ở bước này mới deploy Istio + policy và test lại (AFTER).
>
> Thứ tự các giai đoạn ở mục 6 (GĐ3 chạy trước GĐ4 và GĐ5) đã đúng theo nguyên tắc này — chỉ cần đảm bảo không vô tình cài Pomerium/Istio sớm hơn vì lý do hạ tầng rồi nhầm đó là "before".

### Scenario A — North-South *(attack vector: Identity compromise — mục 3, Vector 1)*

| Actor | Route đích | BEFORE — chưa deploy Pomerium | AFTER — Pomerium identity-aware access control |
|---|---|---|---|
| Guest | `/admin` | ALLOWED | DENIED |
| Staff | `/admin` | ALLOWED | DENIED |
| Admin | `/admin` | ALLOWED | ALLOWED |

### Scenario B — East-West *(attack vector: Workload compromise — mục 3, Vector 2)*

| Workload nguồn (bị compromise) | Workload đích | BEFORE — chưa cài Istio/AuthorizationPolicy | AFTER — Istio mTLS + AuthorizationPolicy |
|---|---|---|---|
| `user-service` | `order-service` | ALLOWED (đúng phạm vi nghiệp vụ) | ALLOWED (vẫn trong phạm vi least-privilege) |
| `user-service` | `admin-service` | ALLOWED (lateral movement thành công — vấn đề cần khắc phục) | DENIED (chặn bởi AuthorizationPolicy) |

**AuthorizationPolicy:**

```yaml
# Policy 1 — gắn vào order-service (selector = destination thật sự)
# Cho phép user-service gọi tới order-service
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-user-to-order
  namespace: crm
spec:
  selector:
    matchLabels:
      app: order-service
  action: ALLOW
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/crm/sa/user-service"]
      to:
        - operation:
            paths: ["/api/orders/*"]
```

```yaml
# Policy 2 — gắn vào admin-service (selector = destination thật sự)
# admin-service KHÔNG cần được gọi bởi bất kỳ service nào khác trong
# scope hiện tại (chỉ được truy cập qua Pomerium ở tầng North-South).
# action: ALLOW + rules rỗng => deny-all cho mọi service-to-service traffic.
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: restrict-admin-service
  namespace: crm
spec:
  selector:
    matchLabels:
      app: admin-service
  action: ALLOW
  rules: []
```

> ⚠️ **Đừng chỉ tin vào YAML vì nó trông hợp lý** — `rules: []` chỉ có ý nghĩa deny-all nếu Istio thực sự evaluate đúng như kỳ vọng. Xem nguyên tắc xác minh ở mục 9 trước khi đánh dấu GĐ5 hoàn thành.

---

## 5. Expected Evidence (bảng demo nhanh)

| Test | Before (kỳ vọng) | After (kỳ vọng) | Evidence |
|---|---|---|---|
| Guest → `/admin` | ALLOWED (~200) | DENIED (~403) | HTTP response + Pomerium log |
| Staff → `/admin` | ALLOWED (~200) | DENIED (~403) | HTTP response + Pomerium log |
| Admin → `/admin` | ALLOWED (~200) | ALLOWED (~200) | HTTP response |
| `user-service` → `order-service` | ALLOWED (~200) | ALLOWED (~200) | Service log |
| `user-service` → `admin-service` | ALLOWED (~200) | DENIED (~403) | Istio policy log |

> Mã HTTP (200/403) là **giá trị kỳ vọng**, không phải invariant tuyệt đối — mã thực tế có thể khác tùy cấu hình. Điều cần chứng minh là **ALLOWED → DENIED**, không phải đúng con số status code.

---

## 6. Bảng kế hoạch triển khai theo giai đoạn

| GĐ | Nhiệm vụ | Chi tiết công việc | Công cụ | Kết quả bàn giao | Thời gian |
|---|---|---|---|---|---|
| 0 | Threat model & định nghĩa test case | Xác định 2 attack vector, assets, expected result của từng test — làm TRƯỚC khi build. | Tài liệu | Threat model + bảng test case kỳ vọng | 1 ngày |
| 1 | Setup cluster & demo app | Dựng cluster Kind/Minikube; deploy 3 service — chưa có Pomerium, chưa cài Istio. | Kind, Docker, kubectl | Cluster + 3 service demo baseline | 2-3 ngày |
| 2 | Dựng Identity Provider | Self-host Keycloak; tạo realm, user, role mẫu (guest/staff/admin). | Keycloak (OIDC) | IdP hoạt động với user/role mẫu | 1-2 ngày |
| 3 | Baseline attack — BEFORE | Test trực tiếp (bypass, chưa deploy Pomerium/Istio) cho cả Scenario A và B — đúng nghĩa "before" theo mục 4. | kubectl exec, curl, port-forward | Log/video bằng chứng "before" cho cả 2 scenario | 1 ngày |
| 4 | Triển khai ZTNA Gateway (North-South) | Cài Pomerium; áp policy theo role/route; verify theo nguyên tắc mục 9; chạy lại Scenario A. | Pomerium + Keycloak OIDC | Gateway hoạt động đúng; bằng chứng "after" Scenario A | 3-4 ngày |
| 5 | Áp mTLS & AuthorizationPolicy (East-West) | Cài Istio; bật mTLS strict + 2 AuthorizationPolicy ở mục 4; verify theo nguyên tắc mục 9; chạy lại Scenario B. | Istio (Linkerd = fallback) | Bằng chứng "after" Scenario B | 3-4 ngày |
| 6 | Đo lường & so sánh Before/After | Tổng hợp latency overhead, số request bị block đúng test case, coverage log. | Script đo latency, Jupyter/Excel | Bảng so sánh Before/After theo số liệu | 1-2 ngày |
| 7* | Nối log về Graylog (không bắt buộc) | Đẩy access log Pomerium + Istio vào Graylog qua GELF. CẮT ĐẦU TIÊN nếu thiếu thời gian. | Graylog, GELF | Access log tập trung, truy vấn được | 2 ngày |
| 8 | Viết báo cáo & làm slide/video demo | Viết báo cáo, dựng slide/video theo bảng Expected Evidence. | Slide, video/screen record | Báo cáo + tài liệu demo hoàn chỉnh | 2-3 ngày |

**Tổng thời gian:** lõi (GĐ0-6, 8 — không gồm Graylog): 14-20 ngày. + Graylog (không bắt buộc): +2 ngày. + Buffer: 3-5 ngày. **Tổng thực tế: khoảng 3-4,5 tuần** làm ngoài giờ hành chính.

> Nếu thiếu thời gian, cắt GĐ7 (Graylog) trước tiên — không cắt attack scenario hay measurement.

---

## 7. Tiêu chí đánh giá thành công

- Chứng minh trực quan được cả 2 scenario theo đúng bảng Expected Evidence — before cho phép, after bị chặn.
- Độ trễ (latency overhead) do Pomerium/Istio gây ra nằm trong ngưỡng chấp nhận được cho một ứng dụng nội bộ.
- 100% test case và security-relevant request được ghi nhận và truy vấn được trong Graylog, nếu GĐ7 được thực hiện.
- Có tài liệu/slide/video trình bày rõ theo cấu trúc: BEFORE North-South → AFTER North-South → BEFORE East-West → AFTER East-West, kèm số liệu so sánh.

---

## 8. Rủi ro & biện pháp giảm thiểu

| Rủi ro | Biện pháp giảm thiểu |
|---|---|
| Cấu hình mTLS/AuthorizationPolicy trên Istio phức tạp, tốn nhiều thời gian hơn dự kiến | Dùng Linkerd làm fallback nếu cần rút ngắn thời gian triển khai |
| Thiếu kinh nghiệm thực chiến với Keycloak/OIDC | Dùng tài liệu chính thức + ví dụ cộng đồng; bắt đầu với cấu hình mẫu tối giản |
| Máy local không đủ tài nguyên khi chạy đồng thời Istio + Keycloak + nhiều service | Cân nhắc chuyển sang GKE sandbox nếu tài nguyên local là điểm nghẽn |
| Threat model/test case định nghĩa chưa đủ cụ thể trước khi build | GĐ0 bắt buộc hoàn thành và review trước khi bắt đầu GĐ1 |
| AuthorizationPolicy viết sai selector, vô tình mở quyền thay vì chặn | Áp dụng nguyên tắc xác minh ở mục 9 trước khi coi GĐ5 hoàn thành |
| Vô tình deploy Pomerium/Istio sớm rồi nhầm đó là trạng thái "before" | Tuân thủ đúng thứ tự GĐ3 → GĐ4 → GĐ5; baseline phải ghi nhận TRƯỚC khi công cụ tương ứng được cài |
| Sa đà thêm component mới (Vault, OPA, Prometheus...) làm phình scope | Kiến trúc đã chốt sau 4 vòng đánh giá — không bổ sung thêm |

---

## 9. Nguyên tắc xác minh trước khi đánh dấu một giai đoạn hoàn thành

Áp dụng cho GĐ4 (Pomerium) và GĐ5 (Istio) — không đánh dấu hoàn thành chỉ vì YAML đã apply thành công:

```
Write policy
     ↓
istioctl analyze (hoặc tương đương kiểm tra cấu hình với Pomerium)
     ↓
Deploy
     ↓
Test ALLOW-case  (ví dụ: Admin → /admin,  user-service → order-service)
     ↓
Test DENY-case   (ví dụ: Guest → /admin,  user-service → admin-service)
     ↓
Chỉ đánh dấu giai đoạn hoàn thành sau khi CẢ HAI test đều cho kết quả đúng kỳ vọng
```

Nguyên tắc này áp dụng cho mọi thay đổi policy trong suốt quá trình triển khai, không chỉ lần đầu.
