#!/bin/sh
# GĐ6 — đo latency round-trip. Chạy TRONG 1 pod debug (curlimages/curl) qua
# `kubectl exec`, không đo từ máy host — tránh cộng dồn overhead của bản
# thân `kubectl exec` (round-trip qua API server) vào từng request, vốn sẽ
# lấn át chênh lệch latency thật (vài ms) đang muốn đo.
#
# Usage: measure-latency.sh <N> <METHOD> <URL> [extra curl args...]
# In ra N dòng thời gian round-trip (giây, số thực) — 1 dòng/request, theo
# %{time_total} của curl (đã bao gồm connect + TLS handshake nếu có + chờ
# response, không tính resolve DNS lần đầu do cùng cluster DNS/service).
set -e
N="$1"
METHOD="$2"
URL="$3"
shift 3

i=1
while [ "$i" -le "$N" ]; do
  curl -s -o /dev/null -w '%{time_total}\n' -X "$METHOD" "$@" "$URL"
  i=$((i + 1))
done
