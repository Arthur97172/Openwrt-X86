#!/bin/sh
# Openwrt 首次运行时
LOGFILE="/tmp/uci-defaults-log.txt"
echo "Starting 99-custom.sh at $(date)" >>$LOGFILE
# 设置默认防火墙规则，方便虚拟机首次访问 WebUI
uci set firewall.@zone[1].input='ACCEPT'

# 设置主机名
uci set system.@system[0].hostname='OpenWrt'
uci set system.@system[0].timezone='CST-8'
uci set system.@system[0].zonename='Asia/Shanghai'

# 设置默认语言为简体中文
uci set luci.main.lang='zh_cn'
# 保存设置
uci commit system
uci commit luci

# 设置所有网口可访问网页终端
uci delete ttyd.@ttyd[0].interface

# --------------------------------------------------
# 1. 枚举“真实可用网口”（DSA / x86 / ARM 通用）
# --------------------------------------------------
ifnames=""
count=0

for iface in /sys/class/net/*; do
    name="$(basename "$iface")"

    case "$name" in
        lo|br-*|docker*|veth*|wlan*|phy*) continue ;;
    esac

    # 只要是能出现在 netifd 里的接口，都算
    count=$((count + 1))
    ifnames="$ifnames $name"
done

ifnames="$(echo "$ifnames" | awk '{$1=$1};1')"

echo "[INFO] detected interfaces: $ifnames (count=$count)" >> "$LOGFILE"

# --------------------------------------------------
# 2. 清理可能存在的旧 WAN / LAN 干扰
# --------------------------------------------------
uci -q delete network.wan
uci -q delete network.wan6

# --------------------------------------------------
# 3. 单网口模式：管理口 DHCP（不会被回退）
# --------------------------------------------------
if [ "$count" -eq 1 ]; then
    mgmt_if="$(echo "$ifnames" | awk '{print $1}')"

    echo "[MODE] single interface -> mgmt DHCP on $mgmt_if" >> "$LOGFILE"

    # 不再使用 lan 这个“高风险名称”
    uci -q delete network.lan
    uci rename network.@interface[0]='mgmt' 2>/dev/null

    uci set network.mgmt=interface
    uci set network.mgmt.device="$mgmt_if"
    uci set network.mgmt.proto='dhcp'
    uci set network.mgmt.force_link='1'

    uci commit network
    exit 0
fi

# --------------------------------------------------
# 4. 多网口模式：WAN + LAN
# --------------------------------------------------
wan_if="$(echo "$ifnames" | awk '{print $1}')"
lan_ifs="$(echo "$ifnames" | cut -d ' ' -f2-)"

echo "[MODE] multi interface -> WAN=$wan_if LAN=$lan_ifs" >> "$LOGFILE"

# WAN
uci set network.wan=interface
uci set network.wan.device="$wan_if"
uci set network.wan.proto='dhcp'

uci set network.wan6=interface
uci set network.wan6.device="$wan_if"
uci set network.wan6.proto='dhcpv6'

# LAN bridge
uci set network.lan=interface
uci set network.lan.device='br-lan'
uci set network.lan.proto='static'
uci set network.lan.ipaddr='192.168.5.1'
uci set network.lan.netmask='255.255.255.0'
uci set network.lan.force_link='1'

# br-lan device
uci -q delete network.br_lan
uci set network.br_lan=device
uci set network.br_lan.name='br-lan'
uci set network.br_lan.type='bridge'

for p in $lan_ifs; do
    uci add_list network.br_lan.ports="$p"
done

uci commit network
echo "[DONE] network init completed" >> "$LOGFILE"
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
