#!/bin/bash
# 在全新的 VPS（Ubuntu 22/24、root）上重建這台 DSH 的最小可用版本
# 用法： bash setup-vps.sh [網域] [埠] [工作目錄]
#   例： bash setup-vps.sh dsh-149-88-70-170.sslip.io 3080 /srv/DSH_Workspace
set -euo pipefail

DOMAIN="${1:-dsh-149-88-70-170.sslip.io}"
PORT="${2:-3080}"
WORKDIR="${3:-/srv/DSH_Workspace}"
HERE="$(cd "$(dirname "$0")" && pwd)"
FILES="$HERE/部署檔"

if [ "$(id -u)" -ne 0 ]; then echo "請用 root 執行" >&2; exit 1; fi

echo "=== 0. 這台機器 ==="
. /etc/os-release 2>/dev/null || true
echo "os=${PRETTY_NAME:-unknown} domain=$DOMAIN port=$PORT workdir=$WORKDIR"

echo "=== 1. 安裝 Node 24 + DSH ==="
bash "$FILES/01-install.sh"
echo "dsh $(dsh --version 2>&1 | head -1)"

echo "=== 2. 登入頁產生器 ==="
install -m 0755 "$FILES/dsh-login-page.sh" /usr/local/bin/dsh-login-page.sh

echo "=== 3. 工作目錄 ==="
mkdir -p "$WORKDIR" /root/.dsh /var/log

echo "=== 4. systemd: dsh-web ==="
sed -e "s#__DOMAIN__#$DOMAIN#g" -e "s#__PORT__#$PORT#g" -e "s#__WORKDIR__#$WORKDIR#g" \
  "$FILES/dsh.service.tpl" > /etc/systemd/system/dsh-web.service
systemctl daemon-reload
systemctl enable --now dsh-web
sleep 3

echo "=== 5. 檢查 ==="
CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/" || true)
echo "本機 $PORT 無 cookie 應回 401，實際=$CODE"
systemctl is-active dsh-web || true

echo
echo "=== 6. 反向代理（Caddy）==="
echo "這台機器目前的 Caddy 跑在容器裡（設定在 /root/caddy-8090/Caddyfile）。"
echo "把下面這段加進該 Caddyfile（或 host 上的 Caddy）後 reload："
echo "------------------------------------------------------------"
sed "s#__DOMAIN__#$DOMAIN#g" "$FILES/caddy-dsh-site.txt"
echo "------------------------------------------------------------"
echo

echo "=== 7. 進入方式 ==="
echo "  - 開 https://$DOMAIN/login/（會自動帶 token 轉跳）"
echo "  - 或取本次 token： grep -o 'token=[A-Za-z0-9_-]*' /var/log/dsh-web.log | tail -1"
echo

echo "=== 8. 選用 ==="
echo "  瀏覽器堆疊（Xvfb + Chrome + Playwright MCP）： bash $FILES/02-browser-stack.sh"
echo "  搶卡監控： bash $FILES/03-grab-watch.sh"
echo
echo "完成。"
