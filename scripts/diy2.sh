#!/bin/bash
# ==========================================
# 🚀 目标设备：x86 / x86_64 (ImmortalWrt)
# 📝 功能：LAN IP 192.168.6.131，添加第三方插件源，开启 BBR 优化
# ❌ 无无线配置（x86 通常无内置无线，或由驱动单独管理）
# ==========================================

set -e

# ================== 1. 修改 LAN IP ==================
sed -i 's/192.168\.[0-9]\{1,3\}\.[0-9]\{1,3\}/192.168.6.131/g' package/base-files/files/bin/config_generate

# ================== 2. 添加第三方软件源（kenzok8） ==================
echo "添加第三方插件源..."
if ! grep -q "kenzo" feeds.conf.default; then
    echo 'src-git kenzo https://github.com/kenzok8/openwrt-packages' >> feeds.conf.default
    echo "已添加 kenzo 源"
fi
if ! grep -q "small" feeds.conf.default; then
    echo 'src-git small https://github.com/kenzok8/small' >> feeds.conf.default
    echo "已添加 small 源"
fi

# 如果需要，可以再添加其他源，例如：
# echo 'src-git lienol https://github.com/Lienol/openwrt-package' >> feeds.conf.default

echo "当前 feeds.conf.default 内容："
cat feeds.conf.default

# ================== 3. 更新 feeds（因为添加了新源，必须重新更新） ==================
./scripts/feeds update -a
./scripts/feeds install -a

# ================== 4. （可选）拉取额外插件包 ==================
# 例如：git clone --depth=1 https://github.com/sirpdboy/luci-app-taskplan.git package/luci-app-taskplan || echo "插件已存在或拉取失败，继续"

# ================== 5. 构建首次开机 UCI 初始化脚本（通用优化） ==================
mkdir -p package/base-files/files/etc/uci-defaults
cat << "EOF" > package/base-files/files/etc/uci-defaults/99-custom-settings
#!/bin/sh

# ========== 开启 BBR 拥塞控制 ==========
if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
fi
if ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
fi
sysctl -p >/dev/null 2>&1

# ========== 可选：关闭 IPv6（如果需要） ==========
# uci set network.lan.ip6assign='0'
# uci commit network

# ========== 自毁 ==========
rm -f /etc/uci-defaults/99-custom-settings
exit 0
EOF

echo "diy2.sh 执行完毕！"
