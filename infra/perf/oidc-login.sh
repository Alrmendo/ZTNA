#!/bin/sh
# GĐ6 — thiết lập session Pomerium 1 lần (OIDC Authorization Code flow qua
# Keycloak, cùng phương pháp đã dùng ở GĐ4/GĐ5) để đo latency (d) chỉ tính
# chi phí request lặp lại, không tính chi phí login one-time.
# Usage: oidc-login.sh <username> <password> <cookiejar>
set -e
USERNAME="$1"
PASSWORD="$2"
JAR="$3"
rm -f "$JAR"

curl -sk -c "$JAR" -L "https://admin.gateway.svc.cluster.local:8080/admin" > /tmp/login.html
LOGIN_ACTION=$(grep -o 'action="[^"]*"' /tmp/login.html | head -1 | sed 's/action="//;s/"$//' | sed 's/\&amp;/\&/g')

curl -sk -o /tmp/login-result.html -i -b "$JAR" -c "$JAR" -L \
  --data-urlencode "username=$USERNAME" \
  --data-urlencode "password=$PASSWORD" \
  --data-urlencode "credentialId=" \
  "$LOGIN_ACTION"

tail -1 /tmp/login-result.html
