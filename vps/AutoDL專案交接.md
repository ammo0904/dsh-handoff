# AutoDL 主機選購頁（Chrome 擴充套件）— 專案交接文件

> 用途：丟給 VPS 上的 DSH，讓它接手繼續開發。
> 產生時間：2026-10-20
> 資料來源：2026-10-19 公司／家中兩份對話紀錄 ＋ 實作當時的決策與實測。
> **注意**：本文件是「需求與決策」的整理，不含原始碼逐行說明；原始碼以 `AutoDL_Monitor_v1.6.5.zip` 為準。

---

## 1. 專案目標（使用者原話）

- 「能不能獨立做成一個網頁界面」「我要依條件篩選主機，然後創建主機」
- 「1.数据盘要能擴容 2.要能挑選CPU核心及記憶體容量」
- 「記憶體會不一樣，跟卡無關」
- 「搜尋區域可以複選」
- 「驅動／CUDA也要有篩選」
- 「自動掃描已經固定60秒？那就要顯示倒數秒數」
- 「能不能設定一段時間如60秒，自動掃描檢查，符合條件會有提醒音，甚至可以telegram 通知？有選項可以自動訂購或不自動訂購，可以設定要訂購多少台主機，達標就停止，自動訂購成功telegram通知」
- 「符合 121 台不對啊，篩選出來應該是0，（離線當然算0）」

## 2. 形態與定位（已定案）

- **形態 A：Chrome 擴充套件全頁**（`page.html`），不是本機網站、不是站內覆蓋。
- 憑證留在 Chrome（沿用 AutoDL 網頁的登入態），擴充套件從頁面 `localStorage` 取 token。
- **建立方式：手動一鍵**（按下 → 顯示價格 → 確認才建立），**不做**「條件成立就自動下單」的預設行為；自動訂購是「可勾選項」，且要先有模擬通知驗證。
- 交付節奏：先「只讀版＋截圖」確認版面 → 再接真實下單（`PAGE_CREATE_ENABLED` 下單鎖）。

## 3. 目錄與檔案（以 1.6.5 為準）

```
AutoDL主機監控-V1/
├─ manifest.json          # MV3；版本號在此（1.6.5）
├─ background.js          # service worker：API 呼叫、token 傳遞、自動訂購狀態機
├─ shared.js              # AdlShared：machineFromRow() 正規化、buildHeaders()
├─ page.html / page.css / page.js   # 全頁篩選＋建立主機介面（本專案主體）
├─ popup/                 # 舊的監控 popup（1.0.0 時代）
├─ content/panel.js|css   # 站內浮動面板（1.0.0 時代）
├─ offscreen.js|html      # 響鈴用
├─ icons/
└─ tools/                 # 開發期檢查腳本（probe / check-ui / test-*.mjs）
```

> 1.0.0 只有 `popup/`＋`content/`＋`background.js`，**沒有 `page.html`**。
> 所以「有沒有 page.html」就是分辨新舊版最快的特徵。

## 4. 資料來源（AutoDL API，已逆向）

| 端點 | 用途 |
|---|---|
| `GET api/v1/user/machine/list` | 主機庫清單（篩選頁的資料來源） |
| `GET api/v1/machine/detail` | 單機詳情（記憶體、資料盤可擴容量） |
| `POST api/v1/order/price/preview` | 建立前取價格 |
| `POST api/v1/order/instance/create/payg` | 建立按量實例（下單） |
| `GET api/v1/region/list` | 區域清單（複選用） |
| `GET api/v1/machine/region/gpu_type` | 區域 × GPU 型號 |

- 認證：`token` 取自 AutoDL 頁面 `localStorage`，標頭由 `AdlShared.buildHeaders(token, appVersion)` 組。
- 呼叫位置：`chrome.scripting.executeScript`（MAIN world）在頁面 context 發 fetch；worker 失敗時 fallback 到頁面。
- 正規化：`AdlShared.machineFromRow(row, 'payg')` → `{ id, alias, region, gpuName, gpuMemoryGB, idle, total, dataDiskExpandGB, driver, cuda, price:{current,discounted}, offline, slotsFull }`

## 5. 篩選條件（頁面上應有）

| 分類 | 條件 |
|---|---|
| 區域 | 複選（多選 popover） |
| GPU | 型號、單卡記憶體、**張數**（idle/total） |
| 規格 | CPU 核心數、記憶體容量（**每台不同，跟卡無關**） |
| 系統 | 驅動版本、CUDA 版本（`99`／空值 = 未知） |
| 狀態 | 只看可租（排除 `offline=true`、`slotsFull`）、資料盤可擴容量門檻 |
| 價格 | 每小時價格上限（含折扣價） |

**一致性鐵律**：卡片顯示的「空閒／總數」必須與 AutoDL 官網主機庫一致；離線主機一律視為 **0 可租**（即使 `idle` 顯示 10）。

## 6. 自動掃描／通知／自動訂購（規格）

| 項目 | 規格 |
|---|---|
| 掃描間隔 | 60 秒（最低 60），畫面必須顯示**倒數秒數** |
| 提醒 | 響鈴（音量可調）＋ 瀏覽器通知 ＋ **Telegram** |
| Telegram | bot `ChiangOrderBot`（859237780）、chat_id `777706306` |
| 自動訂購 | 可勾選；目標台數（預設 1）；達標即停止；每次下單前顯示價格 |
| 通知樣板 | 一般提醒 ／ 🧪【模擬】下單 ／ ✅ 下單成功 |
| 安全鎖 | `PAGE_CREATE_ENABLED` 常數控制是否真的送出建立請求 |

## 7. 版本歷程（1.0.0 → 1.6.5）

| 版本 | 主要變更 |
|---|---|
| 1.0.0（10/15） | 舊版：站內浮動面板監控空閒 GPU＋響鈴；無全頁 |
| 1.3.2 | 全頁 `page.html` 誕生（版面／卡片／建立對話框），資料接上 |
| 1.3.3–1.3.4 | 修正 leading-zero id；顯示 machine alias 取代 hex id；價格／詳情接線 |
| 1.3.5–1.3.8 | 正規化映射修正、`memPerGpu` 顯示、stale sentinel 與 null 顯示修正 |
| 1.4.0 | 區域**複選**上線；巢狀 label 版面修正 |
| 1.4.x–1.5.x | 移除空 CPU 欄、表格欄位收斂、詳情失敗原因顯示 |
| 1.5.x–1.6.x | 驅動／CUDA 篩選、`99=未知` 處理、離線／可租判定、倒數秒數、自動訂購狀態機、Telegram、自我測試（selftest）UI |

## 8. 已知未收尾（昨晚 18:32 之前）

1. **自動訂購的「🧪【模擬】」通知沒跳出來**（Telegram 測試訊息可收到，但倒數歸零後沒有模擬通知）。
2. **離線主機要不要顯示**：使用者主張「離線且 GPU 0 卡可租，就不該露出來」，目前仍在清單中出現。
3. **`99`／空值（未知）** 是否直接排除篩選結果，尚未定案。
4. `234 機` 這類 `offline=true` 但 `idle=10` 的卡片，數字顯示與官網的一致性要再驗一次。

## 9. 驗收清單（改完必須逐項回報實測）

- [ ] 主機庫總數與官網一致（改動前後各截一張圖對照）
- [ ] 離線主機（例：234 機 `e8d94597bf`）在篩選結果中的處理符合預期
- [ ] 區域複選可收合、可清空
- [ ] 驅動／CUDA 篩選：已知值、未知（99）、空值三種情況
- [ ] 倒數秒數會跑、歸零後確實觸發掃描
- [ ] 勾「開啟自動訂購」+ 目標 1 台 → 模擬通知 → 真實下單（`PAGE_CREATE_ENABLED` 打開前先問）
- [ ] Telegram 收到對應訊息，內容含機器別名與價格

## 10. 開發環境（VPS 側，已備好）

| 項目 | 值 |
|---|---|
| DSH | https://dsh-149-88-70-170.sslip.io/login/ |
| 工作區 | `/srv/DSH_Workspace` |
| 瀏覽器 | 有頭 Chrome 155 跑在 Xvfb `:99`，CDP `127.0.0.1:9222`，profile `/root/chrome-profile` |
| 看畫面 | https://vnc-149-88-70-170.sslip.io/vnc.html?autoconnect=1&resize=scale&reconnect=1（`chiang` / 見另一份文件） |
| DSH 操控 | Playwright MCP，工具名前綴 `mcp__browser__`（45 個） |
| 擴充套件目錄 | `/root/ext/AutoDL主機監控-V1`（待上傳） |
| 載入方式 | `chrome.service` 的 ExecStart 加 `--load-extension=... --disable-extensions-except=...` |

## 11. 給接手 DSH 的工作守則

1. **先讀這份文件與 zip 內的 `manifest.json`**，確認版本是 1.6.5，再動手。
2. 改動前先備份整包（`cp -a` 到 `_backup/<時間戳>`），改完用 `systemctl restart chrome` 重新載入擴充套件。
3. 每次改完**必須自己跑一次驗收清單並截圖**，把截圖與數字貼給使用者，不要只說「應該可以」。
4. 涉及**下單**（真的花錢）的動作一律先問，`PAGE_CREATE_ENABLED` 不可自行打開。
5. AutoDL 登入態在 `/root/chrome-profile`；若失效，用 noVNC 由**使用者本人**登入，不要索取帳密。
