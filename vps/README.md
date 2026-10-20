# DSH VPS（149.88.70.170）交接

這台 VPS 上跑的是**同一套 DSH**，但它是常駐的：公司和家裡開瀏覽器進去，看到同一份會話與記憶。

- 入口（永遠用這個）：**https://dsh-149-88-70-170.sslip.io/login/**
- 進不去時：`/login/` 會自動帶最新 token 轉跳；裸網址沒有 cookie 就是 401（正常）

## 這包裡有什麼

```
vps/
├─ setup-vps.sh              一次重建（Node + DSH + systemd + 登入頁）
├─ VPS-運維.md               現況、服務、埠、token、常用指令（最常看這份）
├─ 部署檔/
│  ├─ 01-install.sh          Node 24 + dsh
│  ├─ dsh.service.tpl        dsh-web 的 systemd 範本（網域/埠/工作目錄用 sed 代入）
│  ├─ dsh.service            目前實際在跑的版本（含 149.88.70.170 網域）
│  ├─ dsh-login-page.sh      啟動時把 token 寫進 /login/ 的頁面
│  ├─ caddy-dsh-site.tpl / caddy-dsh-site.txt   Caddy 站台設定
│  ├─ xvfb.service           虛擬螢幕 :99
│  ├─ chrome.service         Chrome + CDP 9222（給 Playwright MCP / noVNC 用）
│  ├─ 02-browser-stack.sh    選用：安裝上面那套瀏覽器堆疊
│  ├─ 03-grab-watch.sh       選用：AutoDL 搶卡監控服務
│  ├─ cordis.patch.yml       VPS profile 的插件設定（含 mcp-browser）
│  └─ package.json           VPS profile 的套件清單
└─ 搶卡監控/                  AutoDL 搶卡監控的程式、設定、systemd
```

## 重建一台新的 VPS（換機 / 加開一台）

在**新機器**上（Ubuntu 22/24、root）：

```bash
# 1) 把這個 vps/ 資料夾傳上去
scp -i ~/.ssh/id_ed25519_vps -r vps/ root@<新IP>:/root/dsh-vps

# 2) SSH 進去執行
ssh -i ~/.ssh/id_ed25519_vps root@<新IP>
bash /root/dsh-vps/setup-vps.sh <你的網域> 3080 /srv/DSH_Workspace
```

`setup-vps.sh` 會：安裝 Node 24 + DSH → 安裝登入頁產生器 → 建 systemd `dsh-web` 並啟動 →
檢查 3080 是否回 401（正確）→ 印出要加進 Caddy 的設定片段 → 印出進入方式。

之後再依需要：
- `bash 部署檔/02-browser-stack.sh`（要讓 VPS 上的 DSH 能操作瀏覽器）
- `bash 部署檔/03-grab-watch.sh`（要跑 AutoDL 搶卡監控）

## 已經裝好的東西（現況）

| 項目 | 值 |
| --- | --- |
| 規格 | **8 核 / 16 GB**（2026-10-20 由 4H8G 升級，關機→開機後生效） |
| 系統磁碟 | 機器上 70 GiB（控制台顯示 90G 尚未反映到 `/dev/vda`） |
| DSH | 0.2.1-rc.2（`@latest`，會自己更新） |
| 服務 | `dsh-web`（3080）、`xvfb`（:99）、`chrome`（9222）、Caddy（443） |
| 工作目錄 | `/srv/DSH_Workspace` |
| 資料 | `/root/.dsh`（憑證、記憶庫、會話、插件） |
| 插件 | meow-memory、dsh-cost-meter、dshmarket、dsh-session-notification、dsh-better-sidebar |
| 瀏覽器工具 | Playwright MCP（`mcp-browser`）→ 45 個 `browser_*` |
| 搶卡監控 | `autodl-grab-watch`（工作目錄 `/root/monitor2`） |

## 常用操作（複製貼上）

```bash
systemctl status dsh-web --no-pager
systemctl restart dsh-web            # 重啟；token 會換，重新用 /login/ 進入
grep -o 'token=[A-Za-z0-9_-]*' /var/log/dsh-web.log | tail -1
tail -50 /var/log/dsh-web.log
npm i -g @deepseek-ai/dsh@latest && systemctl restart dsh-web   # 升級
```

## 交接注意

- **不要**用裸網址 `https://<網域>/` 當入口，沒 cookie 就是 401；一律 `/login/`。
- Caddy 是**同一個容器**在顧 443 與 8090，不要在 host 上再開第二個 caddy（443 衝突）。
- VPS 的工作區是另一台機器：看不到你本機的檔案，要 SSH 或在那邊 clone。
- 家裡的 DSH 也能用 SSH 操作這台（金鑰 `id_ed25519_vps`），所以「VPS 出問題」可以直接叫家裡的 DSH 處理。
