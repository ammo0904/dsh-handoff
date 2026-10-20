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

## 四、要一起帶回家的檔案（可選）

- `DSH引用助手-V2.7.zip`：https://github.com/ammo0904/dsh-quote-helper/releases/download/v2.7.0/dsh-quote-helper-V2.7.zip
- `DSH-Browser-Control-v1.0.17.zip`：https://github.com/caob23/dsh-browser-control/releases/download/v1.0.17/DSH-Browser-Control-v1.0.17.zip

（install.ps1 會自動下載，通常不用手動帶。）
