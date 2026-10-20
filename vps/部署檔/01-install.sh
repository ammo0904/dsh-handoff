#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
echo "=== [1/5] apt update ==="
apt-get update -qq
echo "=== [2/5] install nodejs 24 ==="
curl -fsSL https://deb.nodesource.com/setup_24.x -o /tmp/nodesource_setup.sh
bash /tmp/nodesource_setup.sh >/dev/null 2>&1
apt-get install -y -qq nodejs
echo "node: $(node -v)  npm: $(npm -v)"
echo "=== [3/5] install dsh (latest) ==="
npm i -g @deepseek-ai/dsh@latest --registry=https://registry.npmmirror.com --no-audit --no-fund 2>&1 | tail -5
echo "dsh: $(dsh --version 2>&1 | head -1)"
echo "=== [4/5] dirs ==="
mkdir -p /root/.dsh
echo "=== [5/5] done ==="
