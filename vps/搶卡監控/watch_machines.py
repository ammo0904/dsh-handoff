#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""AutoDL 搶卡監控 — 每 N 秒輪詢主機庫，符合條件就發 Telegram。

用法：
  python3 watch_machines.py --selftest    # 用假資料驗證分類/篩選邏輯（不連網、不需要 token）
  python3 watch_machines.py --once        # 只抓一次並印出結果（需要 token）
  python3 watch_machines.py               # 常駐輪詢（由 systemd 啟動）

設定檔：/root/monitor2/config.json
Token：/root/monitor2/token.txt（就是 www.autodl.com 的 localStorage.token 原文）
Telegram：沿用 /root/monitor/config.json 的 telegram_token / telegram_chat
"""
import json
import os
import sys
import time
import urllib.request
import urllib.error
from datetime import datetime

BASE = os.path.dirname(os.path.abspath(__file__))
CFG_PATH = os.path.join(BASE, "config.json")
STATE_PATH = os.path.join(BASE, "state.json")
LOG_PATH = os.path.join(BASE, "watch.log")
TG_CFG = "/root/monitor/config.json"
API = "https://www.autodl.com/api/v1/user/machine/list"
OFFLINE_CODES = (3, 4, 5, 6)

DEFAULT_CFG = {
    "interval_seconds": 60,
    "app_version": "1.6.5",
    "filters": {
        "regions": [],
        "gpu_names": [],
        "min_idle": 1,
        "min_mem_gb": 0,
        "max_price": None,
        "cuda": None,
        "driver": None,
        "require_expand": False,
        "exclude_offline": True,
    },
    "notify": {"only_new": True, "renotify_minutes": 30, "heartbeat_minutes": 0},
    # 自動搶卡：預設 dry_run（只組單＋通知，不真的送出）
    "order": {
        "enabled": False,
        "dry_run": True,
        "gpu_count": 1,
        "max_price": 2.5,
        "target_count": 1,
        "daily_limit": 1,
        "expand_gb": 0,
        "image_uuid": "",
        "template_file": "order_template.json",
    },
}



def log(msg):
    line = "[%s] %s" % (datetime.now().strftime("%F %T"), msg)
    print(line, flush=True)
    try:
        with open(LOG_PATH, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass


def load_json(path, default):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return default


def save_state(st):
    st["updated_at"] = datetime.now().strftime("%F %T")
    with open(STATE_PATH, "w", encoding="utf-8") as f:
        json.dump(st, f, ensure_ascii=False, indent=2)


# ---------- 站方語意（與 shared.js 對齊） ----------

def num(v):
    try:
        f = float(v)
        return f if f == f else None
    except Exception:
        return None


def effective_idle(row):
    """真正可租卡數：離線=0；實例數已滿=0；否則 gpu_idle_num。"""
    if int(num(row.get("on_line")) or 0) in OFFLINE_CODES:
        return 0
    maxi = num(row.get("max_instance_num"))
    bind = num(row.get("binding_instance_num"))
    if maxi is not None and bind is not None and (maxi - bind) <= 0:
        return 0
    return int(num(row.get("gpu_idle_num")) or 0)


def price_of(row):
    sku = row.get("machine_sku_info") or []
    if not isinstance(sku, list) or not sku:
        return None, None
    entry = sku[0] or {}
    cur = num(entry.get("current_price"))
    cur = cur / 1000.0 if cur is not None else None
    dis = None
    cfg = entry.get("level_config")
    if isinstance(cfg, list) and cfg:
        pick = cfg[0] or {}
        d = num(pick.get("discounted_price"))
        if d is not None:
            dis = d / 1000.0
    elif isinstance(cfg, dict):
        pick = cfg.get("normal_user") or cfg.get("member_user") or cfg
        d = num(pick.get("discounted_price"))
        if d is not None:
            dis = d / 1000.0
    return cur, dis


def gb(bytes_v):
    v = num(bytes_v)
    return None if v is None else int(v // (1024 ** 3))


def normalize(row):
    cur, dis = price_of(row)
    return {
        "id": str(row.get("machine_id") or ""),
        "alias": str(row.get("machine_alias") or ""),
        "region": str(row.get("region_name") or ""),
        "name": "%s / %s" % (row.get("region_name") or "", row.get("machine_alias") or ""),
        "gpu": str(row.get("gpu_name") or ""),
        "mem_gb": gb(row.get("gpu_memory")),
        "idle_raw": int(num(row.get("gpu_idle_num")) or 0),
        "rentable": effective_idle(row),
        "total": int(num(row.get("gpu_number")) or 0),
        "offline": int(num(row.get("on_line")) or 0) in OFFLINE_CODES,
        "expand_gb": gb(row.get("max_data_disk_expand_size")),
        "driver": str(row.get("driver_version") or ""),
        "cuda": str(row.get("highest_cuda_version") or ""),
        "price": dis if dis is not None else cur,
        "price_raw": cur,
    }


def passes(m, f):
    if f.get("exclude_offline", True) and m["rentable"] <= 0:
        return False
    if m["rentable"] < int(f.get("min_idle") or 1):
        return False
    regs = f.get("regions") or []
    if regs and m["region"] not in regs:
        return False
    gpus = f.get("gpu_names") or []
    if gpus and m["gpu"] not in gpus:
        return False
    if int(f.get("min_mem_gb") or 0) and (m["mem_gb"] or 0) < int(f["min_mem_gb"]):
        return False
    if f.get("max_price") is not None and (m["price"] is None or m["price"] > float(f["max_price"])):
        return False
    if f.get("cuda"):
        # 99 與空字串視為未知，不匹配任何指定值
        if m["cuda"] in ("", "99") or m["cuda"] != str(f["cuda"]):
            return False
    if f.get("driver"):
        if not m["driver"] or m["driver"] != str(f["driver"]):
            return False
    if f.get("require_expand") and not (m["expand_gb"] or 0) > 0:
        return False
    return True


# ---------- 網路 ----------

def fetch_rows(cfg):
    try:
        with open(os.path.join(BASE, "token.txt"), encoding="utf-8") as f:
            token = f.read().strip()
    except Exception:
        raise SystemExit("找不到 token.txt（把 localStorage.token 貼進這個檔案）")
    if not token or token == "PASTE_TOKEN_HERE":
        raise SystemExit("token.txt 還是空的")
    body = {
        "charge_type": "payg", "region_sign": "", "gpu_type_name": [], "machine_tag_name": [],
        "gpu_idle_num": 0, "mount_net_disk": False, "instance_disk_size_order": "",
        "date_range": "", "date_from": "", "date_to": "",
        "page_index": 1, "page_size": 100, "pay_price_order": "", "gpu_idle_type": "",
        "default_order": True, "region_sign_list": [],
    }
    req = urllib.request.Request(
        API, data=json.dumps(body).encode("utf-8"), method="POST",
        headers={"Content-Type": "application/json", "Authorization": token,
                 "AppVersion": str(cfg.get("app_version") or "1.6.5")},
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        payload = json.loads(r.read().decode("utf-8", "replace"))
    code = str(payload.get("code") or "")
    if code != "Success":
        raise SystemExit("API 回應 code=%s（登入可能失效）: %s" % (code, str(payload)[:200]))
    data = payload.get("data") or {}
    return data.get("list") or [], data.get("result_total")


def notify(text):
    cfg = load_json(TG_CFG, {})
    token = cfg.get("telegram_token")
    chat = cfg.get("telegram_chat")
    if not token or not chat:
        log("[warn] 沒有 Telegram 設定，只寫 log")
        return False
    data = urllib.parse.urlencode({"chat_id": chat, "text": text}).encode("utf-8")
    try:
        req = urllib.request.Request("https://api.telegram.org/bot%s/sendMessage" % token, data=data)
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.loads(r.read().decode()) .get("ok", False)
    except Exception as e:
        log("[warn] Telegram 發送失敗: %s" % e)
        return False


# ---------- 自動搶卡 ----------

ORDER_API = "https://www.autodl.com/api/v1/order/instance/create/payg"


def load_order_template(cfg):
    name = (cfg.get("order") or {}).get("template_file") or "order_template.json"
    return load_json(os.path.join(BASE, name), None)


def build_order_payload(m, cfg, template):
    """以使用者瀏覽器擷取到的真實 create 請求為底，只覆寫必要欄位。
    沒有 template 就回 None —— 絕不憑猜測組單，避免建出錯誤規格或觸發風控。"""
    if not template:
        return None
    import copy
    payload = copy.deepcopy(template)
    ordc = cfg.get("order") or {}
    for key in ("machine_id", "machineId"):
        if key in payload:
            payload[key] = m["id"]
    for key in ("gpu_num", "gpu_count", "num"):
        if key in payload:
            payload[key] = int(ordc.get("gpu_count") or 1)
    for key in ("expand_disk_size", "data_disk_expand_size", "instance_disk_size"):
        if key in payload:
            payload[key] = int(ordc.get("expand_gb") or 0)
    if ordc.get("image_uuid"):
        for key in ("image_uuid", "imageUuid", "image"):
            if key in payload:
                payload[key] = ordc["image_uuid"]
    return payload


def post_order(payload):
    with open(os.path.join(BASE, "token.txt"), encoding="utf-8") as f:
        token = f.read().strip()
    req = urllib.request.Request(
        ORDER_API, data=json.dumps(payload).encode("utf-8"), method="POST",
        headers={"Content-Type": "application/json", "Authorization": token, "AppVersion": "1.6.5"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode("utf-8", "replace"))


def try_order(m, cfg, state):
    ordc = cfg.get("order") or {}
    if not ordc.get("enabled"):
        return
    if m["price"] is not None and ordc.get("max_price") is not None and m["price"] > float(ordc["max_price"]):
        log("跳過下單：¥%.2f 超過單價上限 ¥%s" % (m["price"], ordc["max_price"]))
        return
    if int(state.get("ordered_today") or 0) >= int(ordc.get("daily_limit") or 1):
        log("跳過下單：今日已下 %s 台（上限 %s）" % (state.get("ordered_today"), ordc.get("daily_limit")))
        return
    payload = build_order_payload(m, cfg, load_order_template(cfg))
    if payload is None:
        log("跳過下單：沒有 order_template.json（真實下單請求範本）")
        notify("⚠️ 自動搶卡開著但缺少 order_template.json，這次沒送出。\n目標：\n" + fmt(m))
        return
    if ordc.get("dry_run", True):
        state["last_dry_run"] = payload
        log("[dry-run] 準備下單：%s" % json.dumps(payload, ensure_ascii=False)[:300])
        notify("🧪【dry-run】符合條件，準備下單（未送出）\n" + fmt(m)
               + "\n\npayload: " + json.dumps(payload, ensure_ascii=False)[:400])
        return
    try:
        resp = post_order(payload)
    except Exception as e:
        log("[order] 送出失敗：%s" % e)
        notify("❌ 下單請求失敗：%s\n目標：%s" % (e, m["name"]))
        return
    ok = str(resp.get("code") or "") == "Success"
    log("[order] 回應：%s" % json.dumps(resp, ensure_ascii=False)[:300])
    if ok:
        state["ordered_today"] = int(state.get("ordered_today") or 0) + 1
        state["ordered_total"] = int(state.get("ordered_total") or 0) + 1
        notify("✅ 下單成功（今日 %s 台）\n%s" % (state["ordered_today"], fmt(m)))
    else:
        notify("⚠️ 下單回應非 Success：code=%s\n%s" % (resp.get("code"), str(resp)[:200]))


def fmt(m):
    p = ""
    if m["price"] is not None:
        p = "¥%.2f/時" % m["price"]
        if m["price_raw"] and m["price_raw"] > m["price"]:
            p += "（原 ¥%.2f）" % m["price_raw"]
    else:
        p = "價格未知"
    return ("%s  %s %sG\n可租 %d/%d｜%s\n資料盤可擴 %s｜驅動 %s｜CUDA %s"
            % (m["name"], m["gpu"], m["mem_gb"] or "?", m["rentable"], m["total"], p,
               ("%d G" % m["expand_gb"]) if m["expand_gb"] is not None else "?",
               m["driver"] or "未知", "未知" if m["cuda"] in ("", "99") else m["cuda"]))


def scan_once(cfg, state, do_notify=True):
    rows, total = fetch_rows(cfg)
    machines = [normalize(r) for r in rows]
    hits = [m for m in machines if passes(m, cfg["filters"])]
    now = time.time()
    seen = state.setdefault("seen", {})
    renotify = int((cfg.get("notify") or {}).get("renotify_minutes") or 30) * 60
    fresh = []
    for m in hits:
        key = "%s|%d" % (m["id"], m["rentable"])
        last = seen.get(key)
        if last is None or now - last > renotify:
            fresh.append(m)
            seen[key] = now
    log("掃描：總 %s 筆、可租 %d、符合 %d、新通知 %d"
        % (total, len([m for m in machines if m["rentable"] > 0]), len(hits), len(fresh)))
    if do_notify and fresh:
        parts = ["🟢 AutoDL 可租 GPU（符合您的條件）\n"]
        for m in fresh[:8]:
            parts.append(fmt(m) + "\n")
        if len(fresh) > 8:
            parts.append("…另有 %d 台\n" % (len(fresh) - 8))
        parts.append("https://www.autodl.com/machine")
        notify("\n".join(parts))
        for m in fresh:
            try_order(m, cfg, state)
    save_state(state)
    return hits


def selftest():
    rows = [
        {"machine_id": "e8d94597bf", "machine_alias": "234机", "region_name": "内蒙B区", "gpu_name": "vGPU-32GB",
         "gpu_memory": 32 * 1024 ** 3, "gpu_idle_num": 10, "gpu_number": 10, "max_instance_num": 10,
         "binding_instance_num": 0, "on_line": 3, "max_data_disk_expand_size": 669 * 1024 ** 3,
         "driver_version": "595.71.05", "highest_cuda_version": "13.2",
         "machine_sku_info": [{"current_price": 1660, "level_config": [{"discounted_price": 1500}]}]},
        {"machine_id": "a1", "machine_alias": "112机", "region_name": "重庆A区", "gpu_name": "RTX-4090",
         "gpu_memory": 24 * 1024 ** 3, "gpu_idle_num": 4, "gpu_number": 8, "max_instance_num": 8,
         "binding_instance_num": 4, "on_line": 1, "max_data_disk_expand_size": 200 * 1024 ** 3,
         "driver_version": "550.54.14", "highest_cuda_version": "12.4",
         "machine_sku_info": [{"current_price": 2100, "level_config": [{"discounted_price": 1980}]}]},
        {"machine_id": "a2", "machine_alias": "118机", "region_name": "重庆A区", "gpu_name": "RTX-4090",
         "gpu_memory": 24 * 1024 ** 3, "gpu_idle_num": 0, "gpu_number": 8, "max_instance_num": 8,
         "binding_instance_num": 8, "on_line": 1, "max_data_disk_expand_size": 200 * 1024 ** 3,
         "driver_version": "550.54.14", "highest_cuda_version": "12.4",
         "machine_sku_info": [{"current_price": 2100, "level_config": [{"discounted_price": 1980}]}]},
        {"machine_id": "b1", "machine_alias": "309机", "region_name": "北京A区", "gpu_name": "A800-80GB",
         "gpu_memory": 80 * 1024 ** 3, "gpu_idle_num": 3, "gpu_number": 4, "max_instance_num": 2,
         "binding_instance_num": 2, "on_line": 1, "max_data_disk_expand_size": 300 * 1024 ** 3,
         "driver_version": "570.86.10", "highest_cuda_version": "13.0",
         "machine_sku_info": [{"current_price": 7500, "level_config": [{"discounted_price": 7500}]}]},
        {"machine_id": "c1", "machine_alias": "507机", "region_name": "西北B区", "gpu_name": "RTX-3090",
         "gpu_memory": 24 * 1024 ** 3, "gpu_idle_num": 2, "gpu_number": 4, "max_instance_num": 4,
         "binding_instance_num": 2, "on_line": 1, "max_data_disk_expand_size": 100 * 1024 ** 3,
         "driver_version": "535.104.05", "highest_cuda_version": "99",
         "machine_sku_info": [{"current_price": 1400, "level_config": [{"discounted_price": 1300}]}]},
    ]
    print("=== selftest：分類（不看篩選） ===")
    for r in rows:
        m = normalize(r)
        print("%-16s %-12s 原idle=%-3d 可租=%-2d 離線=%-5s 可擴=%s GB  CUDA=%r"
              % (m["name"], m["gpu"], m["idle_raw"], m["rentable"], m["offline"], m["expand_gb"], m["cuda"]))
    print("\n=== selftest：不同條件下符合幾台 ===")
    cases = [
        ("預設（只看可租）", {}),
        ("條件：CUDA=13.2", {"cuda": "13.2"}),
        ("條件：CUDA=99（未知，應 0 台）", {"cuda": "99"}),
        ("條件：min_idle=3", {"min_idle": 3}),
        ("條件：區域=西北B区", {"regions": ["西北B区"]}),
        ("條件：require_expand + max_price=2.0", {"require_expand": True, "max_price": 2.0}),
    ]
    base = json.loads(json.dumps(DEFAULT_CFG["filters"]))
    for label, over in cases:
        f = dict(base)
        f.update(over)
        n = len([m for m in (normalize(r) for r in rows) if passes(m, f)])
        print("  %-34s → %d 台" % (label, n))
    print("\n（以上為假資料，邏輯與 shared.js 相同）")


def main():
    cfg = load_json(CFG_PATH, DEFAULT_CFG)
    cfg.setdefault("filters", DEFAULT_CFG["filters"])
    cfg.setdefault("notify", DEFAULT_CFG["notify"])
    if "--selftest" in sys.argv:
        selftest()
        return
    state = load_json(STATE_PATH, {})
    if "--once" in sys.argv:
        hits = scan_once(cfg, state, do_notify=False)
        print("\n=== 符合條件 %d 台 ===" % len(hits))
        for m in hits[:20]:
            print(fmt(m))
            print()
        return
    interval = int(cfg.get("interval_seconds") or 60)
    log("啟動：每 %d 秒掃描一次，條件=%s" % (interval, json.dumps(cfg["filters"], ensure_ascii=False)))
    while True:
        try:
            scan_once(cfg, state)
        except SystemExit as e:
            log("[fatal] %s" % e)
            time.sleep(interval)
        except Exception as e:
            log("[error] %s: %s" % (type(e).__name__, e))
        time.sleep(interval)


if __name__ == "__main__":
    main()
