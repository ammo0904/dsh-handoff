[Unit]
Description=DeepSeek Harness Web (VPS)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment=DSH_HOME=/root/.dsh
Environment=DSH_PROFILE=web
Environment=NODE_ENV=production
WorkingDirectory=__WORKDIR__
ExecStartPre=/usr/bin/truncate -s 0 /var/log/dsh-web.log
ExecStart=/usr/bin/dsh --profile web --host 127.0.0.1 --port __PORT__ --no-open --trusted-host __DOMAIN__
ExecStartPost=/usr/local/bin/dsh-login-page.sh
Restart=always
RestartSec=5
StandardOutput=append:/var/log/dsh-web.log
StandardError=append:/var/log/dsh-web.log

[Install]
WantedBy=multi-user.target
