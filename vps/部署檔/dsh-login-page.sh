#!/bin/bash
# Regenerate a stable /login/ entry page carrying the current process token.
LOG=/var/log/dsh-web.log
DIR=/root/caddy-8090/data/login
token=""
for i in $(seq 1 60); do
  token=$(grep -o 'token=[A-Za-z0-9_-]*' "$LOG" 2>/dev/null | tail -1 | cut -d= -f2)
  if [ -n "$token" ]; then break; fi
  sleep 1
done
if [ -z "$token" ]; then echo "login page: no token found in $LOG"; exit 0; fi
mkdir -p "$DIR"
cat > "$DIR/index.html" <<HTML
<!doctype html>
<html lang="zh-Hant"><head><meta charset="utf-8">
<title>DSH 登入中</title>
<meta http-equiv="refresh" content="0;url=/?token=$token">
</head><body style="font-family:sans-serif;background:#111;color:#ddd;padding:40px">
<p>正在登入 DSH…</p>
<p>若沒有自動跳轉，請按 <a style="color:#8cf" href="/?token=$token">這裡</a>。</p>
</body></html>
HTML
echo "login page updated: token=${token:0:8}..."
