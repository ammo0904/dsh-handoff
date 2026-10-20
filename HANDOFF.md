# 交接單（2026-10-20 公司電腦 → 家裡電腦）

## 一、今天完成了什麼

| 項目 | 狀態 | 位置 |
| --- | --- | --- |
| DSH 引用助手 **V2.7**（框選→引用/複製，引號、換行、多段空行、網址管理、版本提示） | 已發布 | https://github.com/ammo0904/dsh-quote-helper （Release v2.7.0） |
| **DSH Browser Control** 插件 `@caob23/dsh-browser-control` | 已裝進 `web` profile | npm；bridge 在 `ws://127.0.0.1:9777/ws?token=dsh-local` |
| **DSH Browser Control** 瀏覽器擴充套件 v1.0.17 | 已下載解壓 | `%USERPROFILE%\dsh-extensions\DSH-Browser-Control` |
| VPS：DSH Web + Caddy + noVNC + Chrome/Xvfb + Playwright MCP | 已在跑 | 見 [vps/VPS-運維.md](vps/VPS-運維.md) |

## 二、回家安裝（照順序）

### 步驟 1：跑安裝腳本

```powershell
git clone https://github.com/ammo0904/dsh-handoff.git $env:USERPROFILE\dsh-handoff
powershell -ExecutionPolicy Bypass -File $env:USERPROFILE\dsh-handoff\install.ps1
```

腳本會：
- 檢查 node / pnpm / dsh
- 把 `@caob23/dsh-browser-control` 裝進 `web` profile（已裝就跳過）
- 下載並解壓兩個擴充套件到 `%USERPROFILE%\dsh-extensions\`
  - `DSH引用助手-V2`（2.7.0）
  - `DSH-Browser-Control`

### 步驟 2：在瀏覽器載入兩個「未封裝擴充套件」（唯一手動步驟）

用你平常上網的那個瀏覽器（公司這台是 **Brave**，家裡是哪個就開哪個）：

1. 網址列輸入 `brave://extensions`（Chrome 是 `chrome://extensions`）
2. 右上角開「**開發人員模式**」
3. 點「**載入未解壓縮的擴展**」→ 選 `%USERPROFILE%\dsh-extensions\DSH引用助手-V2`
4. 再點一次 → 選 `%USERPROFILE%\dsh-extensions\DSH-Browser-Control`
5. 確認：
   - 「DSH 引用助手」版本 **2.7.0**（popup 標題旁顯示 `v2.7.0`）
   - 「DSH Browser Control」圖示是**綠點呼吸**（已連上 9777）

### 步驟 3：重啟 DSH

關掉原本跑 `dsh web` 的視窗，重新啟動（用你平常的方式，例如 `DSH啟動.bat`）。
重啟後工具列才會出現 `browser_*`（開瀏覽器、點按鈕、讀頁面、截圖…）。

### 步驟 4：驗證

```powershell
powershell -ExecutionPolicy Bypass -File $env:USERPROFILE\dsh-handoff\verify.ps1
```

再對 DSH 說：「用 browser_info 看有沒有連上」，應該回 `dsh-browser-extension 1.0.17`。

## 三、注意事項（踩過的坑）

| 坑 | 說明 |
| --- | --- |
| 擴充套件「重新載入」不會補進已開的分頁 | popup 會顯示新版本，但頁面跑的是舊腳本。**更新後把所有 DSH 分頁按 F5**。V2.7 的「已引用（雙引號 · v2.7.0）」提示就是用來確認這件事。 |
| 同一份擴充套件放兩個資料夾 = 兩個同名項目 | 用固定資料夾 `%USERPROFILE%\dsh-extensions\`，舊的請移除。 |
| 版本只能看 popup 標題 | 工具列圖示不放徽章（你要求的）。 |
| DSH 引用助手只作用在 | `http://127.0.0.1:*`、`http://localhost:*`、`https://dsh-149-88-70-170.sslip.io/*`，其他網址要在 popup 的「啟用網址」自行加入。 |
| 插件裝完沒反應 | 外掛要重啟 DSH 才載入；`browser_*` 工具沒出現就是還沒重啟。 |
| 家裡的 pnpm 版本太舊 | 腳本只檢查有沒有；沒有就先 `npm i -g pnpm`。 |

## 四、VPS（dsh-vps）——這台不用在家裡重裝，但要能重建

VPS `149.88.70.170` 已經在跑，**回家不需要重裝它**；這包裡放的是「現況＋重建能力」：

| 檔案 | 內容 |
| --- | --- |
| `vps/README.md` | 現況、入口、重建步驟、常用操作 |
| `vps/VPS-運維.md` | 服務、埠、token 取得、登入頁原理、瀏覽器堆疊、重建順序 |
| `vps/setup-vps.sh` | 在**全新 VPS** 上一次重建（Node 24 + DSH + systemd + `/login/`） |
| `vps/部署檔/` | 實際在用的 systemd 單元、Caddy 設定、登入頁產生器、profile 設定 |
| `vps/部署檔/02-browser-stack.sh` | 選用：Xvfb + Chrome + Playwright MCP（給 AI 用的瀏覽器） |
| `vps/部署檔/03-grab-watch.sh` | 選用：AutoDL 搶卡監控 |
| `vps/搶卡監控/` | 搶卡監控程式與設定 |

入口永遠是 **https://dsh-149-88-70-170.sslip.io/login/**（`/` 沒有 cookie 會 401，這是正常的）。

換機／加開一台時：`scp -r vps/ root@<新IP>:/root/dsh-vps` → `bash /root/dsh-vps/setup-vps.sh <網域>`，細節看 `vps/README.md`。

## 五、要一起帶回家的檔案（可選）

- `DSH引用助手-V2.7.zip`：https://github.com/ammo0904/dsh-quote-helper/releases/download/v2.7.0/dsh-quote-helper-V2.7.zip
- `DSH-Browser-Control-v1.0.17.zip`：https://github.com/caob23/dsh-browser-control/releases/download/v1.0.17/DSH-Browser-Control-v1.0.17.zip

（install.ps1 會自動下載，通常不用手動帶。）

## 六、第三方依賴政策：browser-control 直接拉作者，不建庫

**結論：不 fork、不另建 repo、不重打包。** 我們只固定「來源＋版本」，讓安裝脚本去作者那裡拿。

| 項目 | 值 |
| --- | --- |
| 插件（npm） | `@caob23/dsh-browser-control`，目前 **v1.0.17** |
| 擴充套件（zip） | `https://github.com/caob23/dsh-browser-control/releases/download/v1.0.17/DSH-Browser-Control-v1.0.17.zip` |
| 上游 | https://github.com/caob23/dsh-browser-control |
| 授權 | **AGPL-3.0**（copyleft） |

### 為什麼不建庫

1. **授權是 AGPL-3.0**：可以安裝、可以當依賴呼叫；但**不要**把它的原始碼併進我們的專案、也不要改一改當成我們的專案發布（AGPL 連「提供網路服務」都要求提供原始碼）。
2. 少一份要維護的東西：作者更新時我們只要改版本號，不必同步 patch。
3. 授權與出處本來就該留在作者那裡，這樣責任歸屬清楚。

### 升級流程（作者出新版時）

1. 開 https://github.com/caob23/dsh-browser-control/releases 看新版本與 release notes（特別看權限有沒有變）
2. 改 `install.ps1` 的兩處：`$BrowserExtUrl` 的版本號、以及 `$PluginName` 後的 npm 版本（或直接 `dsh plugin --profile web add @caob23/dsh-browser-control@<新版>`）
3. 重跑 `install.ps1` → 在瀏覽器擴充頁對 Browser Control 按「重新載入」→ 重啟 DSH
4. 驗證：`browser_info` 回的 `version` 應等於新版

### 若真要鏡像（備援）

只有「作者刪掉 Release、安裝會失敗」時才考慮。鏡像時必須：
- 附上作者的 `LICENSE`（AGPL-3.0）與出處連結
- 不要修改內容、不要改套件名
- 註明「原封不動的備份」

### 權限風險（給未來的自己）

這個擴充有 `debugger` 權限 → **等於能完全操控你的瀏覽器**（含所有已登入的網站）。
- 只在高信任來源安裝；升級前看 release notes 有沒有多要權限
- 不用時可以在擴充頁把它關掉（DSH 的 `browser_*` 工具會失效，其他功能不受影響）
