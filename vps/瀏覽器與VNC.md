# VPS 無頭瀏覽器 + noVNC + DSH 瀏覽器控制

建立於 2026-10-20。目的：讓 VPS 上的 DSH 能「直接改擴充套件 → 直接載入測試 → 截圖驗證 → 交付」，不用您坐在電腦前手動 reload。

## 一、怎麼看畫面（noVNC）

**網址**：https://vnc-149-88-70-170.sslip.io/vnc.html

| 項目 | 值 |
|---|---|
| 帳號 | `chiang` |
| 密碼 | `f983vdn5m6` |

- 這是「真的 Chrome 畫面」，可以自己點、自己打字、自己登入。
- 建議參數（自動連線＋縮放）：`https://vnc-149-88-70-170.sslip.io/vnc.html?autoconnect=1&resize=scale&reconnect=1`
- VPS 對外頻寬只有 0.6～1.2 MB/s，畫面會頓，這是線路限制不是設定問題。

## 二、架構（四個 systemd 服務）

| 服務 | 作用 | 監聽 |
|---|---|---|
| `xvfb` | 虛擬螢幕 `:99`（1600×900×24） | — |
| `chrome` | Google Chrome 155，**有頭**跑在 `:99`，持久 profile `/root/chrome-profile` | CDP `127.0.0.1:9222` |
| `x11vnc` | 把 `:99` 轉成 VNC | `127.0.0.1:5900`（無密碼，只綁 loopback） |
| `novnc` | websockify + noVNC 網頁客戶端 | `127.0.0.1:6080` |

對外一律經 Caddy（`/root/caddy-8090/Caddyfile`，備份 `Caddyfile.bak_before_vnc`）加 basic_auth，`149.88.70.170`→`vnc-149-88-70-170.sslip.io`。

## 三、DSH 怎麼操作瀏覽器

DSH 原生支援 MCP，已加一條 client 設定在 `/root/.dsh/profiles/web/cordis.patch.yml`（備份 `.bak_before_mcp`）：

```yaml
- id: mcp-browser
  name: '@deepseek-ai/dsh-mcp-client'
  config:
    serverName: browser
    transport: stdio
    command: /usr/bin/playwright-mcp
    args: ['--cdp-endpoint', 'http://127.0.0.1:9222', '--caps', 'vision,pdf,devtools', '--allow-unrestricted-file-access']
    toolCallTimeoutMs: 180000
```

工具會以 `mcp__browser__*` 出現，共 **45 個**，常用的：

| 工具 | 用途 |
|---|---|
| `browser_navigate` | 開網址 |
| `browser_take_screenshot` | 截圖（回傳給 DSH，您在聊天裡就看得到） |
| `browser_click` / `browser_type` / `browser_fill_form` | 點擊／輸入／填表 |
| `browser_snapshot` | 取無障礙樹（比截圖更省 token、更精準定位） |
| `browser_console_messages` | 抓 console 錯誤（擴充套件除錯關鍵） |
| `browser_evaluate` | 執行 JS（例：讀 `localStorage` 的 token） |
| `browser_file_upload` | 上傳檔案 |
| `browser_tabs` | 多分頁管理 |

**關鍵**：MCP 連的是 `--cdp-endpoint 127.0.0.1:9222`，接的是**那個已經有您登入態、且載入擴充套件**的 Chrome，所以不是每次都開一台新的乾淨瀏覽器。

## 四、實測數據（2026-10-20）

| 項目 | 結果 |
|---|---|
| Chrome | 155.0.8059.84，CDP `/json/version` 正常 |
| 導航＋截圖 | example.com 標題、URL 正確，PNG 88,679 bytes |
| noVNC | 無帳密 401、帶帳密 200、WS 升級 101 |
| MCP | initialize 成功（Playwright 1.64.0），tools/list 回 **45 個** |
| 記憶體 | 停掉 `qwen-vl` 後可用 **6.6 GB**；Chrome 約 276 MB |
| 磁碟 | 68G，用 30G，剩 38G |

## 五、常用指令（VPS，root）
```bash
systemctl status chrome x11vnc novnc xvfb
systemctl restart chrome        # 換擴充套件／登入態後重啟
curl -s http://127.0.0.1:9222/json/version
tail -20 /var/log/dsh-web.log   # 看 MCP 有沒有報錯
```

## 六、擴充套件測試（下一步）
1. 擴充套件原始碼放 `/root/ext/<資料夾名稱>`。
2. `chrome.service` 的 `ExecStart` 加：
   ```
   --load-extension=/root/ext/<資料夾名稱> --disable-extensions-except=/root/ext/<資料夾名稱>
   ```
   （Chrome 對「未打包擴充套件」只認這種旗標載入，`policy` 方式是另一條路）
3. `systemctl daemon-reload && systemctl restart chrome`
4. 之後改檔案只要 `systemctl restart chrome`，不用手動按「重新載入擴充套件」。

## 七、已知限制
- `qwen-vl`（圖生文）停用中，因為它吃 5.2 GB。要恢復：`systemctl start qwen-vl`（跑瀏覽器前記得再停）。
- 機房 IP：Google 登入、Cloudflare 人機驗證類的網站大概率過不去；要登入的站建議走 noVNC 手動一次，登入態會存在 `/root/chrome-profile`。
- websockify 只綁 loopback，對外必須經 Caddy 的 basic_auth；不要改成 `0.0.0.0`。
