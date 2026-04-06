#!/bin/bash

# 1. 定义版本和架构（amd64v3 是针对现代 CPU 的优化版）
VERSION="3.2.6"
ARCH="amd64v3" 
DOWNLOAD_URL="https://github.com/go-gost/gost/releases/download/v${VERSION}/gost_${VERSION}_linux_${ARCH}.tar.gz"

# 2. 配置信息
PORT="1088"
USER="jklm"
PASS="88699s5"

echo "------------------------------------------------"
echo "正在开始安装 GOST v${VERSION} (${ARCH})..."
echo "------------------------------------------------"

# 3. 下载并安装
wget -O gost.tar.gz "$DOWNLOAD_URL"
if [ $? -ne 0 ]; then
    echo "下载失败，请检查网络或版本号是否正确。"
    exit 1
fi

tar -zxvf gost.tar.gz
sudo mv -f gost /usr/bin/gost
sudo chmod +x /usr/bin/gost
rm -f gost.tar.gz LICENSE README*

# 4. 写入 Systemd 服务文件（实现开机自启）
echo "正在配置 Systemd 服务..."
sudo bash -c "cat << EOM > /etc/systemd/system/gost.service
[Unit]
Description=Gost v3.2.6 Service
After=network.target

[Service]
Type=simple
# GOST v3 监听地址前建议加冒号
ExecStart=/usr/bin/gost -L socks5://$USER:$PASS@:$PORT
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOM"

# 5. 启动服务
sudo systemctl daemon-reload
sudo systemctl enable gost
sudo systemctl restart gost

echo "------------------------------------------------"
echo "安装完成！服务已启动并设置开机自启。"
echo "SOCKS5 端口: $PORT"
echo "用户名: $USER"
echo "密码: $PASS"
echo "查看状态命令: sudo systemctl status gost"
echo "------------------------------------------------"
