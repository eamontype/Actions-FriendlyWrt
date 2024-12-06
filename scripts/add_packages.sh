#!/bin/bash

# {{ Add luci-app-diskman
(cd friendlywrt && {
    mkdir -p package/luci-app-diskman
    wget https://raw.githubusercontent.com/lisaac/luci-app-diskman/master/applications/luci-app-diskman/Makefile -O package/luci-app-diskman/Makefile
    mkdir -p package/parted
    wget https://raw.githubusercontent.com/lisaac/luci-app-diskman/master/Parted.Makefile -O package/parted/Makefile
})
cat >> configs/rockchip/01-nanopi <<EOL
CONFIG_PACKAGE_luci-app-diskman=y
CONFIG_PACKAGE_luci-app-diskman_INCLUDE_btrfs_progs=y
CONFIG_PACKAGE_luci-app-diskman_INCLUDE_lsblk=y
CONFIG_PACKAGE_smartmontools=y
EOL
# }}

# {{ Add luci-app-openclash
(cd friendlywrt && {
    # 克隆 OpenClash 的源代码
    [ -d package/luci-app-openclash ] && rm -rf package/luci-app-openclash
    git clone https://github.com/vernesong/OpenClash.git package/luci-app-openclash --depth 1 -b master
})

# 修改 OpenWrt 配置文件，启用 OpenClash 插件
cat >> configs/rockchip/01-nanopi <<EOL
# 启用 luci-app-openclash
CONFIG_PACKAGE_luci-app-openclash=y
CONFIG_PACKAGE_lm-sensors=y
EOL
# }}

# {{ Add luci-app-vlmcsd
(cd friendlywrt && {
    [ -d package/luci-app-vlmcsd ] && rm -rf package/luci-app-vlmcsd
    git clone https://github.com/cokebar/luci-app-vlmcsd.git package/luci-app-vlmcsd --depth 1 -b master
})

cat >> configs/rockchip/01-nanopi <<EOL
# 启用 luci-app-vlmcsd
CONFIG_PACKAGE_luci-app-vlmcsd=y
CONFIG_PACKAGE_luci-i18n-vlmcsd-zh-cn=y
EOL
# }}

# {{ Add luci-theme-argon
(cd friendlywrt/package && {
    [ -d luci-theme-argon ] && rm -rf luci-theme-argon
    git clone https://github.com/jerrykuku/luci-theme-argon.git --depth 1 -b master
})
echo "CONFIG_PACKAGE_luci-theme-argon=y" >> configs/rockchip/01-nanopi
sed -i -e 's/function init_theme/function old_init_theme/g' friendlywrt/target/linux/rockchip/armv8/base-files/root/setup.sh
cat > /tmp/appendtext.txt <<EOL
function init_theme() {
    if uci get luci.themes.Argon >/dev/null 2>&1; then
        uci set luci.main.mediaurlbase="/luci-static/argon"
        uci commit luci
    fi
}
EOL
sed -i -e '/boardname=/r /tmp/appendtext.txt' friendlywrt/target/linux/rockchip/armv8/base-files/root/setup.sh
# }}
