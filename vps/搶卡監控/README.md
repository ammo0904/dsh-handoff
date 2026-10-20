# AutoDL 搶卡監控（VPS 常駐）

每 60 秒輪詢 AutoDL 主機庫 → 依條件篩選 → **Telegram 通知** →（可選）**自動下單**。

## 檔案
| 檔案 | 用途 |
|---|---|
| `watch_machines.py` | 主程式 |
| `config.json` | 篩選條件、通知、下單設定 |
| `token.txt` | AutoDL 的 `localStorage.token` 原文（**待填**） |
| `order_template.json` | 真實下單請求的 JSON 範本（**待填**，沒有它不會下單） |
| `state.json` | 已通知／已下單紀錄 |
| `watch.log` | 執行紀錄 |

## 三種模式
```bash
python3 watch_machines.py --selftest   # 用假資料驗證分類與篩選（不連網）
python3 watch_machines.py --once       # 抓一次真實資料並印出結果（需 token）
python3 watch_machines.py              # 常駐（systemd: autodl-grab-watch）
```

## 可租判定（與官網一致）
- `on_line ∈ {3,4,5,6}` → 離線 → **可租 0**（即使 `gpu_idle_num` 顯示 10）
- `max_instance_num - binding_instance_num <= 0` → 實例數已滿 → **可租 0**
- 否則 = `gpu_idle_num`

## 安全機制（自動下單）
| 機制 | 說明 |
|---|---|
| `order.enabled` | 預設 **false**，不開啟就只通知 |
| `order.dry_run` | 預設 **true**：只組單＋通知「準備下單」，不送出 |
| `order.max_price` | 單價上限（元/時），超過就跳過 |
| `order.daily_limit` | 每日最多下幾台 |
| `order.target_count` | 達標即停 |
| `order_template.json` | **沒有真實請求範本就不會下單**（避免組出錯誤訂單） |

## 取得 token（使用者本人，1 分鐘）
1. 開 <https://www.autodl.com> 並登入
2. F12 → Console → 貼上 `copy(localStorage.getItem('token'))`
3. 貼到 VPS 的 `/root/monitor2/token.txt`（權限 600）

## 取得下單範本（要做自動搶卡才需要）
1. 在 AutoDL 手動建立一台（或按到最後一步看請求）
2. DevTools → Network → 找 `order/instance/create/payg`
3. 右鍵 → Copy → **Copy as cURL**，貼給助手改寫成 `order_template.json`

## 開機自啟
```bash
systemctl enable --now autodl-grab-watch
systemctl status autodl-grab-watch
tail -f /root/monitor2/watch.log
```
