#!/bin/bash

set -e

# 1. 定义 GOST 版本和架构
VERSION="3.2.6"
ARCH="amd64v3" 
DOWNLOAD_URL="https://github.com/go-gost/gost/releases/download/v${VERSION}/gost_${VERSION}_linux_${ARCH}.tar.gz"

# 2. 配置信息
PORT="1088"
USER="jklm"
PASS="88699s5"

echo "------------------------------------------------"
echo "开始部署 GOST v${VERSION} + 系统网络/并发极限优化..."
echo "------------------------------------------------"

# 3. 解除系统与用户的并发句柄限制 (limits.conf)
echo "[1/5] 优化系统文件句柄限制 (ulimit)..."
if ! grep -q "\* soft nofile 65535" /etc/security/limits.conf; then
    echo "* soft nofile 65535" >> /etc/security/limits.conf
    echo "* hard nofile 65535" >> /etc/security/limits.conf
fi

if ! grep -q "pam_limits.so" /etc/pam.d/common-session; then
    echo "session required pam_limits.so" >> /etc/pam.d/common-session
fi

# 4. 配置网络内核参数 + 开启 BBR 拥塞控制
echo "[2/5] 配置 TCP 内核优化并开启 BBR..."
cat << 'SYSCTL' > /etc/sysctl.d/99-gost-optimize.conf
# 开启 BBR 拥塞控制算法
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# TCP 连接与端口优化
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535
net.core.somaxconn = 32768
net.ipv4.tcp_max_syn_backlog = 16384
SYSCTL

sysctl -p /etc/sysctl.d/99-gost-optimize.conf > /dev/null 2>&1 || sysctl --system > /dev/null 2>&1 || true

# 5. 下载并安装 GOST
echo "[3/5] 下载并安装 GOST v${VERSION} (${ARCH})..."
wget -O gost.tar.gz "$DOWNLOAD_URL"
if [ $? -ne 0 ]; then
    echo "下载失败，请检查网络连接。"
    exit 1
fi

tar -zxvf gost.tar.gz > /dev/null
sudo mv -f gost /usr/bin/gost
sudo chmod +x /usr/bin/gost
rm -f gost.tar.gz LICENSE README*

# 6. 写入包含 LimitNOFILE 的 Systemd 服务文件
echo "[4/5] 配置 Systemd 服务 (注入 LimitNOFILE=65535)..."
sudo bash -c "cat << EOM > /etc/systemd/system/gost.service
[Unit]
Description=Gost v3.2.6 Service
After=network.target

[Service]
Type=simple
LimitNOFILE=65535
ExecStart=/usr/bin/gost -L socks5://$USER:$PASS@:$PORT
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOM"

# 7. 启动服务并刷新配置
echo "[5/5] 启动 GOST 服务..."
sudo systemctl daemon-reload
sudo systemctl enable gost
sudo systemctl restart gost

echo "------------------------------------------------"
echo "部署完成！系统状态验证："
echo "------------------------------------------------"

# 验证 BBR 状态
BBR_STATUS=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
if [ "$BBR_STATUS" = "bbr" ]; then
    echo "✅ BBR 加速状态: 已成功开启 ($BBR_STATUS)"
else
    echo "⚠️ BBR 状态: $BBR_STATUS (如在 OpenVZ/LXC 容器中可能无法开启)"
fi

# 验证 GOST 句柄限制
MAIN_PID=$(systemctl show --property=MainPID gost | cut -d= -f2)
if [ -n "$MAIN_PID" ] && [ "$MAIN_PID" -ne 0 ]; then
    LIMIT=$(cat /proc/$MAIN_PID/limits | grep "Max open files" | awk '{print $4}')
    echo "✅ GOST 允许最大句柄数: $LIMIT"
fi

echo "------------------------------------------------"
echo "SOCKS5 端口: $PORT"
echo "用户名: $USER"
echo "密码: $PASS"
echo "查看运行日志: sudo journalctl -u gost -f"
echo "------------------------------------------------"
