# 給 DSH AI 的執行規格（交接用）

> 你（家裡的 DSH）收到這份檔案後，照下列步驟自己做，不需要使用者輸入指令。
> 環境：Windows、PowerShell 5.1、node/pnpm/dsh 已安裝（缺的話見步驟 0）。

## 步驟 0：環境自檢

```powershell
node -v; pnpm -v; dsh --version
```

- `pnpm` 缺失 → `npm i -g pnpm`（需要網路）
- `dsh` 缺失 → `npm i -g @deepseek-ai/dsh`
- 任一缺失且無法補 → 停止並回報「缺 X，無法繼續」

## 步驟 1：取得交接包

```powershell
git clone https://github.com/ammo0904/dsh-handoff.git $env:USERPROFILE\dsh-handoff
```

（已有就 `git -C $env:USERPROFILE\dsh-handoff pull --ff-only`）

## 步驟 2：一鍵安裝

```powershell
powershell -ExecutionPolicy Bypass -File $env:USERPROFILE\dsh-handoff\install.ps1
```

期望輸出：`pnpm/dsh OK`、插件已安裝或已存在、兩個擴充套件解壓到 `%USERPROFILE%\dsh-extensions\`。
腳本 exit code 0 = 成功；2 = 缺工具；3 = 下載失敗。

## 步驟 3：引導使用者手動載入擴充套件（不可代做）

Chrome/Brave 禁止程式載入未封裝擴充，**必須請使用者按**。請你用「一次講完、不要分次問」的方式給：

1. 開 `brave://extensions`（或 `chrome://extensions`）
2. 開「開發人員模式」
3. 「載入未解壓縮的擴展」→ 選 `C:\Users\<使用者>\dsh-extensions\DSH引用助手-V2`
4. 再一次 → 選 `C:\Users\<使用者>\dsh-extensions\DSH-Browser-Control`
5. 確認：引用助手版本是 **2.7.0**；Browser Control 圖示**綠點呼吸**

同時用 `Start-Process explorer.exe "<路徑>"` 幫他把資料夾打開，減少找路徑的時間。

## 步驟 4：重啟 DSH

外掛只在 DSH 啟動時載入。請使用者關掉原本的 `dsh web` 視窗後重開（例：`%USERPROFILE%\.dsh\DSH啟動.bat`）。

> 重啟會中斷你目前的會話，重啟後再繼續驗證。先告訴使用者「重啟後回來跟我說一聲」。

## 步驟 5：驗證（重啟後執行）

```powershell
powershell -ExecutionPolicy Bypass -File $env:USERPROFILE\dsh-handoff\verify.ps1
```

再用工具驗證：

1. `browser_info` → 應回 `dsh-browser-extension 1.0.17` 與瀏覽器版本
2. `browser_tabs list` → 應列出使用者分頁
3. 引用助手：請使用者開 DSH 頁面，框選任一句 → 出現「引用」「複製」→ 按引用 → 輸入框應得到 `“…”` 且游標在下一行；右下應跳「已引用（雙引號 · v2.7.0）」
4. 若引用行為正確但沒有版本提示 → 該分頁是舊腳本，請使用者按 `F5`

## 失敗處理

| 症狀 | 處理 |
| --- | --- |
| `ERR_PNPM_NO_MATCHING_VERSION` | 鏡像沒同步：改用 `dsh plugin --profile web add @caob23/dsh-browser-control --registry=https://registry.npmjs.org/` |
| `ERR_PNPM_NO_MATURE_MATCHING_VERSION` | 版本太新被 24 小時包齡政策擋：等滿 24h，或改用 Release 離線包 `dsh plugin --profile web add file:<解壓目錄>` |
| 插件裝了但沒有 `browser_*` 工具 | 沒重啟 DSH |
| `browser_info` 回 `extension_offline` | 擴充套件沒載入，或 port/token 不符（應為 `9777` / `dsh-local`） |
| 引用沒引號 | 該分頁跑舊腳本 → `F5`；仍舊 → 擴充套件頁按「重新載入」再 `F5` |
| 兩個同名擴充項目 | 移除舊的，只留 `%USERPROFILE%\dsh-extensions\` 這兩份 |

## 不要做的事

- 不要用 `--load-extension` 命令列載入未封裝擴充（Chrome 155 已封鎖，會靜默失敗）
- 不要改 `manifest.json` 的 matches 來加網址 —— 用 popup 的「啟用網址」由使用者自己加
- 不要刪 `%USERPROFILE%\.dsh\profiles\web\package.json` 的既有依賴
