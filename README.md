# DSH 交接包（2026-10-20）

今天在公司電腦完成的東西，回家用同一套方式一鍵裝好。

## 一句話安裝（回家後）

在 PowerShell 貼上：

```powershell
git clone https://github.com/ammo0904/dsh-handoff.git $env:USERPROFILE\dsh-handoff
powershell -ExecutionPolicy Bypass -File $env:USERPROFILE\dsh-handoff\install.ps1
```

**沒有 git 的話**（改用 zip 下載）：

```powershell
$zip = "$env:TEMP\dsh-handoff.zip"
Invoke-WebRequest -UseBasicParsing "https://github.com/ammo0904/dsh-handoff/archive/refs/heads/main.zip" -OutFile $zip
Expand-Archive $zip -DestinationPath "$env:USERPROFILE\dsh-handoff" -Force
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\dsh-handoff\dsh-handoff-main\install.ps1"
```

或者直接對家裡的 DSH 說：

> 讀 `https://github.com/ammo0904/dsh-handoff` 的 `HANDOFF.md`，照著裝。

## 內容

| 檔案 | 用途 |
| --- | --- |
| [HANDOFF.md](HANDOFF.md) | 人看的交接單：今天做了什麼、怎麼裝、要注意什麼 |
| [AGENT.md](AGENT.md) | **給 DSH AI 看的執行規格**（步驟、驗證條件、失敗處理） |
| [install.ps1](install.ps1) | 能自動做的全部做完（檢查環境、裝插件、下載解壓兩個擴充套件） |
| [verify.ps1](verify.ps1) | 裝完後的檢查清單 |
| [vps/README.md](vps/README.md) | **DSH VPS 交接**：現況、入口、重建腳本、常用操作 |
| [vps/setup-vps.sh](vps/setup-vps.sh) | 在新 VPS 上一次重建（Node + DSH + systemd + 登入頁） |
| [vps/部署檔/](vps/部署檔/) | systemd 單元、Caddy 設定、登入頁產生器、profile 設定、瀏覽器堆疊與搶卡監控腳本 |
| [vps/VPS-運維.md](vps/VPS-運維.md) | VPS 運維細節（token、登入、服務、重建順序） |

## 今天交付的兩樣東西

1. **DSH 引用助手 V2.7**（瀏覽器擴充套件）
   - 原始碼＋版本：https://github.com/ammo0904/dsh-quote-helper
   - 最新 Release：v2.7.0
2. **DSH Browser Control**（讓 AI 直接操作你已登入的瀏覽器）
   - 插件：`@caob23/dsh-browser-control`（npm，裝進 web profile）
   - 擴充套件：`DSH-Browser-Control-v1.0.17.zip`

兩者都是「未封裝擴充套件」，**最後一步一定要你（或家人）在瀏覽器按一下**——Chrome/Brave 不允許程式代載，這是安全機制。
