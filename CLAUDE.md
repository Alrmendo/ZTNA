# CLAUDE.md — ZTNA Lab Demo

Nguồn sự thật duy nhất cho project này là [docs/PLAN.md](docs/PLAN.md). Đọc kỹ toàn bộ file này trước khi làm bất cứ điều gì. Các nguyên tắc dưới đây bắt buộc tuân thủ trong suốt quá trình triển khai.

- Không mở rộng kiến trúc/thêm công cụ ngoài PLAN.md (không Vault, OPA, Falco, Prometheus, Grafana, ArgoCD, NetworkPolicy... trừ khi được yêu cầu rõ ràng).
- Triển khai đúng thứ tự GĐ0 → GĐ8 trong PLAN.md, không nhảy giai đoạn.
- "BEFORE" trong mỗi scenario nghĩa là trạng thái THẬT SỰ chưa có công cụ tương ứng (Pomerium/Istio) được deploy — không phải deploy xong rồi để policy mở. Luôn ghi evidence BEFORE trước khi cài công cụ của giai đoạn đó.
- Trước khi đánh dấu GĐ4 hoặc GĐ5 hoàn thành, PHẢI áp dụng nguyên tắc xác minh ở mục 9 PLAN.md: write policy → istioctl analyze (hoặc kiểm tra tương đương với Pomerium) → deploy → test ALLOW-case → test DENY-case → chỉ đánh dấu hoàn thành sau khi cả 2 test đúng kỳ vọng.
- Sau mỗi giai đoạn: tóm tắt đã làm gì, evidence thu được, có khớp Expected Evidence trong PLAN.md không, rồi DỪNG LẠI chờ xác nhận trước khi sang giai đoạn tiếp theo.
