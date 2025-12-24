#!/bin/sh
# ==================================================
# OpenWrt First Boot - Production Network Init
# ==================================================

LOGFILE="/tmp/uci-defaults-log.txt"
echo "=== 99-custom.sh start: $(date) ===" >> "$LOGFILE"

# --------------------------------------------------
# 0. 阻止 board.d / init.d/network 覆盖（关键）
# --------------------------------------------------
touch /etc/config/.network_done

# --------------------------------------------------
# 1. 基础系统设置
# --------------------------------------------------
uci set system.@system[0].hostname='OpenWrt'
uci set system.@system[0].timezone='CST-8'
uci set system.@system[0].zonename='Asia/Shanghai'
uci commit system

uci set luci.main.lang='zh_cn'
uci commit luci

# 放开防火墙 LAN 输入，方便首次访问
uci set firewall.@zone[1].input='ACCEPT'
uci commit firewall

# ttyd 允许所有接口访问
uci -q delete ttyd.@ttyd[0].interface
uci commit ttyd

# SSH 允许所有接口
uci set dropbear.@dropbear[0].Interface=''
uci commit dropbear

# --------------------------------------------------
# 2. 枚举真实物理网口（通用 / 稳定）
# --------------------------------------------------
ifnames=""
count=0

for iface in /sys/class/net/*; do
    name="$(basename "$iface")"

    case "$name" in
        lo|br-*|docker*|veth*|wlan*|phy*) continue ;;
    esac

    count=$((count + 1))
    ifnames="$ifnames $name"
done

ifnames="$(echo "$ifnames" | awk '{$1=$1};1')"
echo "[INFO] detected interfaces: $ifnames (count=$count)" >> "$LOGFILE"

# --------------------------------------------------
# 3. 清理所有旧网络配置（防止污染）
# --------------------------------------------------
rm -f /etc/config/network
touch /etc/config/.network_done

uci -q delete network.lan
uci -q delete network.wan
uci -q delete network.wan6
uci -q delete network.mgmt
uci -q delete network.br_lan

# --------------------------------------------------
# --------------------------------------------------
if [ "$count" -eq 1 ]; then
    lan_if="$(echo "$ifnames" | awk '{print $1}')"

    echo "[MODE] SINGLE NIC -> lan DHCP on $lan_if" >> "$LOGFILE"

    # 明确创建 / 覆盖 lan
    uci set network.lan=interface
    uci set network.lan.device="$lan_if"
    uci set network.lan.proto='dhcp'

    # 删除一切 static 遗留字段（非常关键）
    uci -q delete network.lan.ipaddr
    uci -q delete network.lan.netmask
    uci -q delete network.lan.gateway
    uci -q delete network.lan.dns
    uci -q delete network.lan.force_link

    # 确保不存在 bridge
    uci -q delete network.br_lan

    uci commit network
    echo "[DONE] single nic DHCP lan applied" >> "$LOGFILE"
    exit 0
fi
# --------------------------------------------------
# 5. 多网口：WAN + LAN（路由模式）
# --------------------------------------------------
wan_if="$(echo "$ifnames" | awk '{print $1}')"
lan_ifs="$(echo "$ifnames" | cut -d ' ' -f2-)"

echo "[MODE] MULTI NIC -> WAN=$wan_if LAN=$lan_ifs" >> "$LOGFILE"

# WAN
uci set network.wan=interface
uci set network.wan.device="$wan_if"
uci set network.wan.proto='dhcp'

uci set network.wan6=interface
uci set network.wan6.device="$wan_if"
uci set network.wan6.proto='dhcpv6'

# LAN bridge
uci set network.br_lan=device
uci set network.br_lan.name='br-lan'
uci set network.br_lan.type='bridge'

for p in $lan_ifs; do
    uci add_list network.br_lan.ports="$p"
done

uci set network.lan=interface
uci set network.lan.device='br-lan'
uci set network.lan.proto='static'
uci set network.lan.ipaddr='__IPADDR__'
uci set network.lan.netmask='255.255.255.0'
uci set network.lan.force_link='1'

uci commit network
echo "[DONE] multi nic router configured" >> "$LOGFILE"

# --------------------------------------------------
# 6. 写入版本描述
# --------------------------------------------------
sed -i "s/DISTRIB_DESCRIPTION='[^']*'/DISTRIB_DESCRIPTION='OpenWrt VERXXXX'/" \
    /etc/openwrt_release

# --------------------------------------------------
# 7. 自定义软件源
# --------------------------------------------------
cat >> /etc/opkg/customfeeds.conf <<EOF
src/gz openwrt_kiddin9 https://dl.openwrt.ai/packages-24.10/x86_64/kiddin9/
EOF

echo "=== 99-custom.sh end ===" >> "$LOGFILE"
exit 0

# 设置所有网口可连接 SSH
uci set dropbear.@dropbear[0].Interface=''
uci commit

# 设置作者描述信息
FILE_PATH="/etc/openwrt_release"
NEW_DESCRIPTION="OpenWrt VERXXXX"
sed -i "s/DISTRIB_DESCRIPTION='[^']*'/DISTRIB_DESCRIPTION='$NEW_DESCRIPTION'/" "$FILE_PATH"

# 写入自定义软件源到 customfeeds.conf
cat >> /etc/opkg/customfeeds.conf <<EOF
src/gz openwrt_kiddin9 https://dl.openwrt.ai/packages-24.10/x86_64/kiddin9/
EOF

exit 0
