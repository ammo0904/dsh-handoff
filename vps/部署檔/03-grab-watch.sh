#!/bin/bash
# 選用：安裝 AutoDL 搶卡監控（watch_machines.py）
# 這支只是「監控 + 通知 + dry-run」，不會真的下單
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/搶卡監控"
DST=/root/monitor2

if [ ! -d "$SRC" ]; then echo "找不到 $SRC"; exit 1; fi
mkdir -p "$DST"
cp -f "$SRC/watch_machines.py" "$DST/" 2>/dev/null || true
cp -f "$SRC/config.json" "$DST/" 2>/dev/null || true
cp -f "$SRC/README.md" "$DST/" 2>/dev/null || true
cp -f "$SRC/搶卡任務交接.md" "$DST/" 2>/dev/null || true

if [ -f "$SRC/autodl-grab-watch.service" ]; then
  install -m 0644 "$SRC/autodl-grab-watch.service" /etc/systemd/system/autodl-grab-watch.service
  systemctl daemon-reload
  systemctl enable --now autodl-grab-watch
  systemctl is-active autodl-grab-watch || true
  echo "日誌： tail -f $DST/service.log"
fi
echo "完成。設定檔在 $DST/config.json（token、通知 webhook 等請自行填入）"
