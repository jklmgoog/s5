#!/bin/bash

# 定义版本和架构（这里选 v3 优化版，如果报错请改回 amd64）
VERSION="3.2.6"
ARCH="amd64v3" 
DOWNLOAD_URL="https://github.com/go-gost/gost/releases/download/v${VERSION}/gost_${VERSION}_linux_${ARCH}.tar.gz"

PORT="1088"
USER="jklm"
PASS="88699s5"

# 1. 下载并安装
echo "正在安装 GOST v${VERSION} (${ARCH})..."
wget -O gost.tar.gz "$DOWNLOAD_URL"
tar -zxvf gost.tar.gz
sudo mv -f gost /usr/bin/gost
sudo chmod +x /usr/bin/gost
rm -f gost.tar.gz LICENSE README*

# 2. 写入或更新 Systemd 服务
sudo bash -c "cat << EOM > /etc/systemd/system/gost.service
[Unit]
Description=Gost v3.2.6 Service
After=network.target

[Service]
Type=simple
# GOST v3 建议在监听地址前加冒号
ExecStart=/usr/bin/gost -L socks5://$USER:$PASS@:$PORT
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOM"

# 3. 启动并设置自启
sudo systemctl daemon-reload
sudo systemctl enable gost
sudo systemctl restart gost

echo "------------------------------------------------"
echo "GOST v${VERSION} 已部署完成！"
echo "状态检查：sudo systemctl status gost"
echo "------------------------------------------------"
EOF
