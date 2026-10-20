# VPS 運維備忘（149.88.70.170）

> 這份是「回家自己重建／重啟」用的。日常不用碰。
>
> 同資料夾的其他檔案：`setup-vps.sh`（新機一次重建）、`部署檔/`（實際在用的 systemd、Caddy、登入頁、profile 設定）、`搶卡監控/`（AutoDL 監控）。先看 [README.md](README.md) 的「這包裡有什麼」。

## 連線

| 項目 | 值 |
| --- | --- |
| IP / 主機名 | `149.88.70.170`（Ubuntu 24.04，host `ser802369270163`） |
| SSH 使用者 | `root` |
| 金鑰（公司機） | `~/.ssh/id_ed25519_vps`（`ssh -i ~/.ssh/id_ed25519_vps root@149.88.70.170`） |
| 對外網址 | `https://dsh-149-88-70-170.sslip.io/` |

## 常駐服務（systemd）

| 服務 | 內容 | 埠 |
| --- | --- | --- |
| `dsh-web.service` | `dsh --profile web --host 127.0.0.1 --port 3080 --no-open --trusted-host dsh-149-88-70-170.sslip.io`，`DSH_HOME=/root/.dsh`，日誌 `/var/log/dsh-web.log` | 127.0.0.1:3080 |
| `caddy`（`/root/caddy-8090/Caddyfile`） | https 反向代理：`/login/*` → 靜態登入頁；其餘 → 127.0.0.1:3080；另有 `vnc-…sslip.io` 走 basic auth → 127.0.0.1:6080 | 443 / 8090 |
| `chrome.service` | Chrome 155 headful（Xvfb :99），`--remote-debugging-port=9222`（只綁 127.0.0.1）、`--user-data-dir=/root/chrome-profile` | 9222 |
| `xvfb.service` | 虛擬顯示 `:99`（1600x900） | — |
| noVNC | `https://vnc-149-88-70-170.sslip.io/`（basic auth）→ 6080 | 6080 |

## 登入 / token（最常踩）

DSH 認證用 token 換 cookie；**重啟 dsh-web 後舊 token 失效**，原本開著的分頁會變
`dsh web authentication required`。

- 正常入口：**`https://dsh-149-88-70-170.sslip.io/login/`**（Caddy 的登入頁，內含最新 token，自動轉跳）
- 查目前 token：
  ```bash
  grep -o 'token=[A-Za-z0-9_-]*' /var/log/dsh-web.log | tail -1
  ```
- 直接用 token：`https://dsh-149-88-70-170.sslip.io/?token=<token>`
- 登入頁由 `/usr/local/bin/dsh-login-page.sh` 產生（`dsh-web.service` 的 `ExecStartPost`），輸出到 `/root/caddy-8090/data/login/index.html`

## 常用操作

```bash
systemctl status dsh-web --no-pager
systemctl restart dsh-web          # 重啟 DSH（token 會換，重新用 /login/ 進入）
journalctl -u dsh-web -n 50 --no-pager
tail -50 /var/log/dsh-web.log

systemctl restart chrome           # 重啟給 AI 用的瀏覽器
ss -ltnp | grep -E '3080|9222|9777'
```

## 給 AI 用的瀏覽器（Playwright MCP）

- 全域套件：`@playwright/mcp`（`/usr/bin/playwright-mcp`）
- profile 設定：`/root/.dsh/profiles/web/cordis.patch.yml` 的 `mcp-browser`
  - `--cdp-endpoint http://127.0.0.1:9222`
  - `--caps vision,pdf,devtools --allow-unrestricted-file-access`
  - `failOnStartupError: false`（MCP 掛掉不會擋 DSH，但工具會消失）
- 驗證：`node /tmp/mcp-probe.mjs`（會列 45 個 `browser_*` 工具）

## 已裝的 DSH profile 插件

`dsh-session-notification`、`dsh-better-sidebar`、`dsh-cost-meter`、`dshmarket`、`meow-memory`

## 重建順序（換機時）

1. `apt install -y google-chrome-stable xvfb`
2. 建立 `xvfb.service`（`:99`）與 `chrome.service`（`--remote-debugging-port=9222`）
3. `npm i -g @deepseek-ai/dsh @playwright/mcp`
4. `dsh --profile web --host 127.0.0.1 --port 3080 --trusted-host <你的網域>`（建議做成 systemd）
5. Caddy 反向代理 + `/login/` 靜態頁（或直接用 `?token=` 進入）
6. 在 `cordis.patch.yml` 加 `mcp-browser`（見上）
7. 驗證：`curl -s -o /dev/null -w '%{http_code}' https://<你的網域>/login/`、`node /tmp/mcp-probe.mjs`
