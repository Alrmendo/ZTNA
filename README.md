# ZTNA Lab Demo

Đây là một **security experiment** — có hypothesis, baseline, controlled attack, mitigation và measurable result — minh họa kiến trúc Zero Trust Network Access (ZTNA) bằng thực nghiệm trên Kubernetes, không phải một sản phẩm hay cấu hình production. Dùng làm portfolio/demo kỹ thuật.

## Thesis

> Có identity hợp lệ không đồng nghĩa có toàn quyền truy cập (**valid identity ≠ unlimited access**).
> Một workload bị compromise không đồng nghĩa toàn cluster bị compromise (**compromised workload ≠ cluster-wide access**).

*(nguyên văn security objective — [THREAT_MODEL.md](docs/THREAT_MODEL.md))*

## Kiến trúc

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
| Graylog | Observability / audit | Tập trung log để hỗ trợ giám sát liên tục. | Không phải cơ chế enforcement — chỉ hỗ trợ continuous monitoring. Xem trạng thái SKIPPED bên dưới. |

*(nguyên văn mục 2 — [PLAN.md](docs/PLAN.md))*

## Trạng thái hiện tại

- [x] **GĐ0 — Threat model & test case** — DONE (`d73919d`)
- [x] **GĐ1 — Setup cluster & demo app** — DONE (`3eac693`)
- [x] **GĐ2 — Dựng Identity Provider (Keycloak)** — DONE (`6b627e1`)
- [x] **GĐ3 — Baseline attack BEFORE** — DONE (`8cab70d`) — evidence: [docs/evidence/gd3-before/](docs/evidence/gd3-before/)
- [x] **GĐ4 — Triển khai Pomerium (North-South)** — DONE (`6e5609d`) — verify ALLOW/DENY theo mục 9 PLAN.md, evidence: [docs/evidence/gd4-after/](docs/evidence/gd4-after/)
- [x] **GĐ5 — mTLS + AuthorizationPolicy (East-West)** — DONE (`36a9988`) — verify ALLOW/DENY theo mục 9 PLAN.md, kèm regression check Scenario A, evidence: [docs/evidence/gd5-after/](docs/evidence/gd5-after/); chi tiết sự cố/khắc phục: [docs/NOTES.md](docs/NOTES.md)
- [x] **GĐ6 — Đo lường & so sánh Before/After** — DONE (`b55173d`) — evidence: [docs/evidence/gd6-measurement/](docs/evidence/gd6-measurement/)
- [ ] **GĐ7 — Nối log về Graylog** — SKIPPED. Lý do: tiêu chí "100% security-relevant request được ghi nhận" (PLAN.md mục 7) đã PASS ở GĐ6 (222/222 request đối chiếu được ở nguồn log Pomerium + Istio, coverage 100% — xem [MEASUREMENT.md § Coverage log](docs/MEASUREMENT.md#3-coverage-log)) mà không cần Graylog. PLAN.md mục 6 cũng ghi rõ GĐ7 là hạng mục cắt đầu tiên nếu không bắt buộc.
- [ ] **GĐ8 — Viết báo cáo & slide/video demo** — PENDING. README này tổng hợp phần báo cáo dạng văn bản; slide/video demo chưa được tạo.

## Kết quả nổi bật

| Test | Before | After |
|---|---|---|
| Guest → `/admin` | ALLOWED (200) | **DENIED (403)** — `claim-unauthorized` |
| Staff → `/admin` | ALLOWED (200) | **DENIED (403)** — `claim-unauthorized` |
| Admin → `/admin` | ALLOWED (200) | ALLOWED (200) |
| `user-service` → `order-service` | ALLOWED (200) | ALLOWED (200) — vẫn trong phạm vi least-privilege |
| `user-service` → `admin-service` | ALLOWED (200) — lateral movement thành công | **DENIED (403)** — Istio RBAC, `rbac_access_denied_matched_policy[none]` |

Chi tiết đầy đủ: [docs/TEST_CASES.md](docs/TEST_CASES.md), [docs/MEASUREMENT.md](docs/MEASUREMENT.md).

## Số liệu đo lường (GĐ6)

- **Latency overhead** (giá trị tuyệt đối, mean): East-West +3.04 ms (+102.7%), North-South +10.00 ms (+495.0%) — cả hai đều dưới 15ms, chấp nhận được cho ứng dụng nội bộ.
- **Consistency check** (N=20/case, DENY-case): guest→/admin, staff→/admin, user-service→admin-service đều **20/20 DENIED** — 0 leak / 60 request.
- **Log coverage**: 222/222 security-relevant request đối chiếu được ở log Pomerium + Istio/Envoy — **100%**.

Số liệu đầy đủ + phương pháp đo: [docs/MEASUREMENT.md](docs/MEASUREMENT.md).

## Cấu trúc repo

```
docs/       Threat model, test case, kế hoạch, đo lường, ghi chú sai khác, evidence thô
infra/      Manifest K8s/kustomize cho Keycloak, Pomerium, Istio, script đo latency
services/   3 service demo dạng CRM: user-service, order-service, admin-service
```

## Cách tái tạo lại từ đầu

1. **GĐ1** — Dựng cluster Kind + deploy 3 service baseline: `kind create cluster --config infra/k8s/kind-config.yaml` rồi `kubectl apply -f infra/k8s/`.
2. **GĐ2** — Deploy Keycloak + import realm `crm`: `kubectl apply -k infra/keycloak/` — chi tiết: [infra/keycloak/README.md](infra/keycloak/README.md).
3. **GĐ3** — Test trực tiếp `/admin` và `user-service → admin-service` **trước khi** cài Pomerium/Istio, lưu evidence BEFORE — xem [docs/TEST_CASES.md](docs/TEST_CASES.md).
4. **GĐ4** — Deploy Pomerium, verify theo nguyên tắc mục 9 PLAN.md (analyze → deploy → ALLOW-case → DENY-case): `kubectl apply -k infra/pomerium/` — chi tiết: [infra/pomerium/README.md](infra/pomerium/README.md).
5. **GĐ5** — Cài Istio, bật mTLS STRICT + AuthorizationPolicy, verify theo cùng nguyên tắc — chi tiết + thứ tự lệnh: [infra/istio/README.md](infra/istio/README.md), sai khác so với PLAN.md gốc: [docs/NOTES.md](docs/NOTES.md).
6. **GĐ6** — Đo latency overhead + consistency + log coverage: `infra/perf/measure-latency.sh`, `infra/perf/check-status.sh`, tổng hợp bằng `infra/perf/aggregate.py` — chi tiết: [docs/MEASUREMENT.md](docs/MEASUREMENT.md).

*(GĐ7 — Graylog — không thực hiện, xem lý do ở mục Trạng thái hiện tại.)*

## Disclaimer — đây là lab, không phải production

- **Keycloak chạy dev mode** (`start-dev`), DB H2 in-memory/ephemeral (mất dữ liệu khi pod bị recreate), không TLS — xem [infra/keycloak/README.md](infra/keycloak/README.md).
- **Credential test hardcode trong `realm-export.json`** (`guest-user`/`staff-user`/`admin-user` với mật khẩu cố định, admin console `admin`/`admin`) — chỉ dùng cho lab, không dùng ngoài môi trường này.
- **TLS của Pomerium là self-signed, lab-only** (`infra/pomerium/tls-lab-only/`, 10 năm, tự ký) — không dùng cert này ngoài lab.
- **Secret của Pomerium hardcode sẵn** (`IDP_CLIENT_SECRET`/`COOKIE_SECRET`/`SHARED_SECRET` trong `infra/pomerium/secret.yaml`) để reproducible qua git — không phải thực hành production.
- **Istio dùng profile `demo`** (`istioctl install --set profile=demo`) — profile khuyến nghị cho lab/getting-started, không phải cấu hình production; version 1.28.10 được chọn vì tương thích với Kubernetes 1.30.0 của cluster Kind hiện có (nhánh 1.28 đã EOL upstream) — xem [docs/NOTES.md](docs/NOTES.md).

## Tài liệu chi tiết

- [docs/PLAN.md](docs/PLAN.md) — kế hoạch triển khai, nguồn sự thật duy nhất của project
- [docs/THREAT_MODEL.md](docs/THREAT_MODEL.md) — threat model, attack vector, security objective
- [docs/TEST_CASES.md](docs/TEST_CASES.md) — checklist test case Before/After
- [docs/MEASUREMENT.md](docs/MEASUREMENT.md) — đo lường latency, consistency, log coverage
- [docs/NOTES.md](docs/NOTES.md) — sai khác phát sinh trong lúc triển khai so với PLAN.md gốc
