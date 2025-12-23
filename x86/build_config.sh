#!/bin/bash
# 此脚本在Imagebuilder 根目录运行
source custom-packages.sh
echo "第三方软件包: $CUSTOM_PACKAGES"
LOGFILE="/tmp/uci-defaults-log.txt"
echo "Starting 99-custom.sh at $(date)" >> $LOGFILE
echo "Include Docker: $INCLUDE_DOCKER"

if [ -z "$CUSTOM_PACKAGES" ]; then
  echo "⚪️ 未选择 任何第三方软件包"
else
  # ============= 同步第三方插件库==============
  # 同步第三方软件仓库run/ipk
  echo "🔄 正在同步第三方软件仓库 Cloning run file repo..."
  git clone --depth=1 https://github.com/wukongdaily/store.git /tmp/store-run-repo

  # 拷贝 run/x86 下所有 run 文件和ipk文件 到 extra-packages 目录
  mkdir -p extra-packages
  cp -r /tmp/store-run-repo/run/x86/* extra-packages/

  echo "✅ Run files copied to extra-packages:"
  ls -lh extra-packages/*.run
  # 解压并拷贝ipk到packages目录
  sh prepare-packages.sh
  echo "打印imagebuilder/packages目录结构"
  ls -lah packages/ |grep partexp
fi

# 输出调试信息
echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始构建固件..."

# ============= iStoreOS仓库内的插件==============
# 定义所需安装的包列表 下列插件你都可以自行删减

# 初始化变量
PACKAGES=""

# 基础系统与驱动
PACKAGES="$PACKAGES base-files"
PACKAGES="$PACKAGES block-mount"
PACKAGES="$PACKAGES ca-bundle"
PACKAGES="$PACKAGES dnsmasq-full"
PACKAGES="$PACKAGES -dnsmasq"
PACKAGES="$PACKAGES dropbear"
PACKAGES="$PACKAGES fdisk"
PACKAGES="$PACKAGES firewall4"
PACKAGES="$PACKAGES fstools"
PACKAGES="$PACKAGES grub2-bios-setup"
PACKAGES="$PACKAGES i915-firmware-dmc"
PACKAGES="$PACKAGES kmod-8139cp"
PACKAGES="$PACKAGES kmod-8139too"
PACKAGES="$PACKAGES kmod-button-hotplug"
PACKAGES="$PACKAGES kmod-e1000e"
PACKAGES="$PACKAGES kmod-fs-f2fs"
PACKAGES="$PACKAGES kmod-i40e"
PACKAGES="$PACKAGES kmod-igb"
PACKAGES="$PACKAGES kmod-igbvf"
PACKAGES="$PACKAGES kmod-igc"
PACKAGES="$PACKAGES kmod-ixgbe"
PACKAGES="$PACKAGES kmod-ixgbevf"
PACKAGES="$PACKAGES kmod-nf-nathelper"
PACKAGES="$PACKAGES kmod-nf-nathelper-extra"
PACKAGES="$PACKAGES kmod-nft-offload"
PACKAGES="$PACKAGES kmod-pcnet32"
PACKAGES="$PACKAGES kmod-r8101"
PACKAGES="$PACKAGES kmod-r8125"
PACKAGES="$PACKAGES kmod-r8126"
PACKAGES="$PACKAGES kmod-r8168"
PACKAGES="$PACKAGES kmod-tulip"
PACKAGES="$PACKAGES kmod-usb-hid"
PACKAGES="$PACKAGES kmod-usb-net"
PACKAGES="$PACKAGES kmod-usb-net-asix"
PACKAGES="$PACKAGES kmod-usb-net-asix-ax88179"
PACKAGES="$PACKAGES kmod-usb-net-rtl8150"
PACKAGES="$PACKAGES kmod-vmxnet3"
PACKAGES="$PACKAGES libc"
PACKAGES="$PACKAGES libgcc"
PACKAGES="$PACKAGES libustream-openssl"
PACKAGES="$PACKAGES logd"
PACKAGES="$PACKAGES luci-app-package-manager"
PACKAGES="$PACKAGES luci-compat"
PACKAGES="$PACKAGES luci-lib-base"
PACKAGES="$PACKAGES luci-lib-ipkg"
PACKAGES="$PACKAGES luci-light"
PACKAGES="$PACKAGES mkf2fs"
PACKAGES="$PACKAGES mtd"
PACKAGES="$PACKAGES netifd"
PACKAGES="$PACKAGES nftables"
PACKAGES="$PACKAGES odhcp6c"
PACKAGES="$PACKAGES odhcpd-ipv6only"
PACKAGES="$PACKAGES opkg"
PACKAGES="$PACKAGES partx-utils"
PACKAGES="$PACKAGES ppp"
PACKAGES="$PACKAGES ppp-mod-pppoe"
PACKAGES="$PACKAGES procd-ujail"
PACKAGES="$PACKAGES uci"
PACKAGES="$PACKAGES uclient-fetch"
PACKAGES="$PACKAGES urandom-seed"
PACKAGES="$PACKAGES urngd"
PACKAGES="$PACKAGES kmod-amazon-ena"
PACKAGES="$PACKAGES kmod-amd-xgbe"
PACKAGES="$PACKAGES kmod-bnx2"
PACKAGES="$PACKAGES kmod-e1000"
PACKAGES="$PACKAGES kmod-dwmac-intel"
PACKAGES="$PACKAGES kmod-forcedeth"
PACKAGES="$PACKAGES kmod-fs-vfat"
PACKAGES="$PACKAGES kmod-tg3"
PACKAGES="$PACKAGES kmod-drm-i915"
PACKAGES="$PACKAGES -libustream-mbedtls"

# LuCI 中文本地化与插件
PACKAGES="$PACKAGES luci-i18n-package-manager-zh-cn"
PACKAGES="$PACKAGES luci-i18n-argon-zh-cn"
PACKAGES="$PACKAGES luci-i18n-argon-config-zh-cn"
PACKAGES="$PACKAGES luci-i18n-filetransfer-zh-cn"
PACKAGES="$PACKAGES luci-i18n-quickstart-zh-cn"
PACKAGES="$PACKAGES luci-i18n-base-zh-cn"
PACKAGES="$PACKAGES luci-i18n-firewall-zh-cn"
PACKAGES="$PACKAGES luci-i18n-ttyd-zh-cn"
PACKAGES="$PACKAGES luci-i18n-cifs-mount-zh-cn"
PACKAGES="$PACKAGES luci-i18n-unishare-zh-cn"
PACKAGES="$PACKAGES luci-i18n-dockerman-zh-cn"

# LuCI 主题与功能
PACKAGES="$PACKAGES luci-theme-argon"
PACKAGES="$PACKAGES luci-app-argon-config"
PACKAGES="$PACKAGES luci-app-filetransfer"
PACKAGES="$PACKAGES luci-app-ttyd"
PACKAGES="$PACKAGES luci-app-cifs-mount"

# SFTP 支持
PACKAGES="$PACKAGES openssh-sftp-server"
PACKAGES="$PACKAGES coreutils"

# 追加自定义包
PACKAGES="$PACKAGES $CUSTOM_PACKAGES"


# 若构建openclash 则添加内核
if echo "$PACKAGES" | grep -q "luci-app-openclash"; then
    echo "✅ 已选择 luci-app-openclash，添加 openclash core"
    mkdir -p files/etc/openclash/core
    # Download clash_meta
    META_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-amd64.tar.gz"
    wget -qO- $META_URL | tar xOvz > files/etc/openclash/core/clash_meta
    chmod +x files/etc/openclash/core/clash_meta
    # Download GeoIP and GeoSite
    wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat -O files/etc/openclash/GeoIP.dat
    wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat -O files/etc/openclash/GeoSite.dat
else
    echo "⚪️ 未选择 luci-app-openclash"
fi

# 构建镜像
echo "开始构建......打印所有包名===="
echo "$PACKAGES"


# 开始构建
make image PROFILE=generic PACKAGES="$PACKAGES" FILES="files" ROOTFS_PARTSIZE=2048

if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Build failed!"
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - 构建成功."