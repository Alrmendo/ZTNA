#!/bin/sh
# GĐ6 — kiểm tra tính nhất quán (consistency): chạy lại N lần 1 DENY-case
# đã xác nhận ở GĐ4/GĐ5, in ra mã HTTP từng lần.
# Usage: check-status.sh <N> <METHOD> <URL> [extra curl args...]
set -e
N="$1"
METHOD="$2"
URL="$3"
shift 3

i=1
while [ "$i" -le "$N" ]; do
  curl -s -o /dev/null -w '%{http_code}\n' -X "$METHOD" "$@" "$URL"
  i=$((i + 1))
done
