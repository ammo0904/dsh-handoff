#!/bin/bash
# 選用：安裝給 AI 用的瀏覽器堆疊（Xvfb + Chrome for Testing + Playwright MCP）
# 只在使用者要「讓 VPS 上的 DSH 能操作瀏覽器」時才需要
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "=== 1. 系統套件 ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq xvfb curl unzip python3 ca-certificates fonts-noto-cjk

echo "=== 2. Chrome for Testing ==="
if [ ! -x /opt/chrome-linux64/chrome ]; then
  URL=$(curl -fsSL https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json \
    | python3 -c "import sys,json;d=json.load(sys.stdin);print([x['url'] for x in d['channels']['Stable']['downloads']['chrome'] if x['platform']=='linux64'][0])")
  echo "下載 $URL"
  curl -fsSL "$URL" -o /tmp/chrome.zip
  unzip -q -o /tmp/chrome.zip -d /opt
  rm -f /tmp/chrome.zip
  chmod +x /opt/chrome-linux64/chrome
else
  echo "已存在 /opt/chrome-linux64/chrome，跳過"
fi

echo "=== 3. Playwright MCP ==="
npm i -g @playwright/mcp --registry=https://registry.npmmirror.com --no-audit --no-fund
echo "playwright-mcp: $(which playwright-mcp || echo /usr/bin/playwright-mcp)"

echo "=== 4. systemd: xvfb + chrome ==="
install -m 0644 "$HERE/xvfb.service" /etc/systemd/system/xvfb.service
install -m 0644 "$HERE/chrome.service" /etc/systemd/system/chrome.service
systemctl daemon-reload
systemctl enable --now xvfb
systemctl enable --now chrome
sleep 3
if systemctl is-active --quiet chrome; then echo "chrome: active"; else echo "chrome 啟動失敗，看 journalctl -u chrome -n 50"; fi

echo "=== 5. 驗證 CDP ==="
if curl -fsS http://127.0.0.1:9222/json/version >/dev/null; then
  echo "CDP 9222 OK"
else
  echo "CDP 9222 沒有回應（等幾秒再試，或看 journalctl -u chrome）"
fi

cat <<'TIP'

=== 6. 讓 DSH 掛上 Playwright MCP ===
在 /root/.dsh/profiles/web/cordis.patch.yml 加上（或合併）：

- insert:
    - id: mcp-browser
      name: '@deepseek-ai/dsh-mcp-client'
      config:
        serverName: browser
        transport: stdio
        command: /usr/bin/playwright-mcp
        args: ['--cdp-endpoint', 'http://127.0.0.1:9222', '--caps', 'vision,pdf,devtools', '--allow-unrestricted-file-access']
        toolCallTimeoutMs: 180000
        failOnStartupError: false

然後 systemctl restart dsh-web，用 `node 工具/mcp-probe.mjs` 驗證工具清單。
TIP
