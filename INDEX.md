# 全部交付物索引（避免遺漏）

一次看完「今天/這段時間」做完的東西在哪裡。回家只需要第一節的兩步，其餘是備份與重建用的。

## 一、回家要用到的（只有這兩個）

| 要什麼 | 去哪拿 |
| --- | --- |
| 本機安裝（引用助手 + 瀏覽器控制） | 這個 repo：`git clone https://github.com/ammo0904/dsh-handoff.git` → `install.ps1` → 看 `HANDOFF.md` |
| 給 DSH 自己讀的規格 | 這個 repo 的 `AGENT.md` |

## 二、GitHub 上的所有 repo

| Repo | 內容 | 最新 |
| --- | --- | --- |
| [dsh-handoff](https://github.com/ammo0904/dsh-handoff) | 交接包：安裝腳本、AGENT/HANDOFF、VPS 交接與重建腳本 | main `78b02f0` 之後 |
| [dsh-quote-helper](https://github.com/ammo0904/dsh-quote-helper) | **DSH 引用助手**擴充套件原始碼＋測試工具＋V1 舊版 | Release **v2.7.0** |
| [autodl-monitor](https://github.com/ammo0904/autodl-monitor) | **AutoDL 主機 GPU 監控**擴充套件原始碼 | main |
| [dsh-conversation-sync](https://github.com/ammo0904/dsh-conversation-sync) | DSH 跨裝置對話同步插件（較早的專案） | v0.5.2 |

## 三、Release 資產（安裝包）

| 檔案 | 位置 |
| --- | --- |
| `dsh-quote-helper-V2.7.zip` | https://github.com/ammo0904/dsh-quote-helper/releases/download/v2.7.0/dsh-quote-helper-V2.7.zip |
| `DSH-Browser-Control-v1.0.17.zip` | https://github.com/caob23/dsh-browser-control/releases/download/v1.0.17/DSH-Browser-Control-v1.0.17.zip（第三方） |
| AutoDL 監控擴充 | 目前沒有上 Release，直接 clone `autodl-monitor` 用「載入未解壓縮的擴展」 |

> **第三方政策**：`dsh-browser-control` **直接拉作者**（npm `@caob23/dsh-browser-control` v1.0.17 ＋ 作者 Release 的 zip），**不 fork、不建庫**。
> 授權是 **AGPL-3.0**，所以不要把它的程式碼併進我們的 repo。細節見 `HANDOFF.md` 第六節。

## 四、VPS（dsh-vps）

全部在 `vps/`：

- 現況與操作：`vps/README.md`、`vps/VPS-運維.md`、`vps/使用說明.md`、`vps/瀏覽器與VNC.md`
- 重建：`vps/setup-vps.sh`（＋`vps/部署檔/`）
- 瀏覽器堆疊：`vps/部署檔/02-browser-stack.sh`
- 搶卡監控：`vps/搶卡監控/`、`vps/部署檔/03-grab-watch.sh`
- AutoDL 專案背景：`vps/AutoDL專案交接.md`
- 小工具：`vps/工具/`（cdp-shot.mjs、mcp-probe.mjs、verify-mock.mjs、mock-http.service）

入口：https://dsh-149-88-70-170.sslip.io/login/

## 五、公司這台電腦上的原始資料（沒有上 GitHub 的部分）

這些是「工作現場」的原檔，不需要上傳也能重建，但列出來避免你以為漏了：

| 路徑 | 內容 |
| --- | --- |
| `C:\Users\admin\Desktop\Test\Chrome擴充套件\DSH引用助手-V2` | 引用助手開發資料夾（＝repo 內容） |
| `C:\Users\admin\Desktop\Test\Chrome擴充套件\DSH引用助手-V1` | V1 原始碼（已備份到 repo 的 `legacy/V1/`） |
| `C:\Users\admin\Desktop\Test\Chrome擴充套件\_工具\lexical-test` | 測試工具（已備份到 repo 的 `tools/`） |
| `C:\Users\admin\Desktop\Test\Chrome擴充套件\*.zip` | 各版本安裝包（Release 上都有同名 ASCII 檔） |
| `C:\Users\admin\Desktop\DSH-VPS` | VPS 專案工作副本（已備份到 `vps/`） |
| `C:\Users\admin\Desktop\Test\.tools\github-cli` | gh CLI 可攜版 |
| `C:\Users\admin\.ssh\id_ed25519_vps` | VPS SSH 金鑰（**不要**上傳） |

## 六、沒上傳的東西（刻意）

- SSH 私鑰、`.dsh/.credentials.yaml`、API key、GitHub token
- AutoDL token、各服務的 cookie
- 測試截圖 PNG（`DSH-VPS\工具\mock*.png`、`shot.png`）：只是驗證證據
