# Threat Model — ZTNA Lab Demo

> Trích nguyên văn từ mục 3 của [PLAN.md](./PLAN.md). Đây là nguồn tham chiếu nhanh — nếu có sai khác, PLAN.md là nguồn sự thật.

Project thực nghiệm **2 attack vector riêng biệt**, mỗi vector ứng với đúng một scenario.

## Vector 1 — Identity compromise (dùng cho Scenario A / North-South)
- Attacker có được credential hợp lệ của một user thông thường (ví dụ qua phishing/leak).
- Attacker **chưa** chiếm được bất kỳ workload nào trong cluster.
- Câu hỏi kiểm chứng: một identity hợp lệ nhưng sai role có truy cập được route ngoài phạm vi của mình không?

## Vector 2 — Workload compromise (dùng cho Scenario B / East-West)
- Attacker khai thác lỗ hổng ứng dụng giả lập để chiếm được `user-service` (không phải qua credential riêng lẻ).
- Attacker có quyền thực thi trong ngữ cảnh của `user-service`, tức gọi được các service khác bằng chính identity/service account của `user-service`.
- Câu hỏi kiểm chứng: một workload bị compromise có di chuyển ngang được sang service ngoài phạm vi cần thiết không?

**Giả định chung cho cả 2 vector:** không có quyền truy cập Kubernetes control-plane; không có cluster-admin; không thể chỉnh sửa policy đã cấu hình.

**Tài sản cần bảo vệ (assets):** `admin-service` và dữ liệu quản trị; dữ liệu user, dữ liệu order; Identity Provider (Keycloak).

**Security objective:**
> Có identity hợp lệ không đồng nghĩa có toàn quyền truy cập (**valid identity ≠ unlimited access**).
> Một workload bị compromise không đồng nghĩa toàn cluster bị compromise (**compromised workload ≠ cluster-wide access**).
