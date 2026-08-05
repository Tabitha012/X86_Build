#!/bin/bash
# ==========================================
# 🚀 目标设备：x86 / x86_64 (ImmortalWrt)
# 📝 功能：
#   1. LAN IP 修改为 192.168.6.131
#   2. 添加第三方插件源 (kenzok8)
#   3. 直接固化 BBR 配置到固件
#   4. 构建首次开机 UCI 初始化脚本（备用优化）
# ❌ 无无线配置（x86 通常无内置无线，或由驱动单独管理）
# ==========================================

set -e

echo "=========================================="
echo "   diy2.sh 开始执行 (x86 定制脚本)"
echo "=========================================="

# ==========================================
# 1. 修改默认 LAN IP 为 192.168.6.131
# ==========================================
echo "正在修改默认 LAN IP 为 192.168.6.131..."
sed -i 's/192.168\.[0-9]\{1,3\}\.[0-9]\{1,3\}/192.168.6.131/g' package/base-files/files/bin/config_generate
echo "LAN IP 修改完成。"

# ==========================================
# 2. 添加第三方软件源（kenzok8）
# ==========================================
echo "正在添加第三方插件源..."
if ! grep -q "kenzo" feeds.conf.default; then
    echo 'src-git kenzo https://github.com/kenzok8/openwrt-packages' >> feeds.conf.default
    echo "✅ 已添加 kenzo 源"
else
    echo "⚠️ kenzo 源已存在，跳过"
fi

if ! grep -q "small" feeds.conf.default; then
    echo 'src-git small https://github.com/kenzok8/small' >> feeds.conf.default
    echo "✅ 已添加 small 源"
else
    echo "⚠️ small 源已存在，跳过"
fi

# 可选的额外源（按需取消注释）
# if ! grep -q "lienol" feeds.conf.default; then
#     echo 'src-git lienol https://github.com/Lienol/openwrt-package' >> feeds.conf.default
#     echo "已添加 lienol 源"
# fi

echo "当前 feeds.conf.default 内容："
echo "----------------------------------------"
cat feeds.conf.default
echo "----------------------------------------"

# ==========================================
# 3. 更新 feeds（必须！让新源生效）
# ==========================================
echo "正在更新 feeds..."
./scripts/feeds update -a
./scripts/feeds install -a
echo "feeds 更新完成。"

# ==========================================
# 4. （可选）拉取额外插件包
# ==========================================
# 如果有需要从 git 单独拉取的插件，可以在这里添加
# 例如：
# echo "正在拉取额外插件..."
# git clone --depth=1 https://github.com/sirpdboy/luci-app-taskplan.git package/luci-app-taskplan || echo "插件已存在或拉取失败，继续"

# ==========================================
# 5. 直接固化 BBR 配置到固件中（编译时写入）
# ==========================================
echo "正在固化 BBR 配置到固件..."
mkdir -p package/base-files/files/etc

# 写入 sysctl.conf（如果尚未存在相关配置）
if ! grep -q "net.core.default_qdisc=fq" package/base-files/files/etc/sysctl.conf 2>/dev/null; then
    echo "net.core.default_qdisc=fq" >> package/base-files/files/etc/sysctl.conf
    echo "✅ 已添加 net.core.default_qdisc=fq"
fi

if ! grep -q "net.ipv4.tcp_congestion_control=bbr" package/base-files/files/etc/sysctl.conf 2>/dev/null; then
    echo "net.ipv4.tcp_congestion_control=bbr" >> package/base-files/files/etc/sysctl.conf
    echo "✅ 已添加 net.ipv4.tcp_congestion_control=bbr"
fi

echo "BBR 配置已写入固件的 /etc/sysctl.conf"

# ==========================================
# 6. 构建首次开机 UCI 初始化脚本（备用）
#    如果第5步已固化，此脚本作为双保险，且可添加其他 UCI 设置
# ==========================================
echo "正在构建首次开机初始化脚本..."
mkdir -p package/base-files/files/etc/uci-defaults
cat << "EOF" > package/base-files/files/etc/uci-defaults/99-custom-settings
#!/bin/sh

# ========== 开启 BBR（双保险，如果 sysctl.conf 未生效） ==========
if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
fi
if ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
fi
sysctl -p >/dev/null 2>&1

# ========== 可选：关闭 IPv6（如需要，取消注释） ==========
# uci set network.lan.ip6assign='0'
# uci commit network

# ========== 可选：修改默认主题（如需要） ==========
# uci set luci.main.mediaurlbase="/luci-static/argon"
# uci commit luci

# ========== 自毁 ==========
rm -f /etc/uci-defaults/99-custom-settings
exit 0
EOF

echo "✅ 首次开机初始化脚本已创建 (99-custom-settings)"

# ==========================================
# 7. 完成
# ==========================================
echo "=========================================="
echo "   diy2.sh 执行完毕！"
echo "=========================================="
