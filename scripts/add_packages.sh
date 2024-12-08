#!/bin/bash

# 日志输出
log() {
    echo "[INFO] $1"
}

# 下载并保存文件到指定路径
download_file() {
    local url=$1
    local dest=$2
    log "Downloading $url to $dest"
    if ! wget -q "$url" -O "$dest"; then
        echo "[ERROR] Failed to download $url" >&2
        exit 1
    fi
}

# 克隆 git 仓库到指定目录
clone_repo() {
    local repo_url=$1
    local dest_dir=$2
    local branch=${3:-master}
    log "Cloning $repo_url into $dest_dir"
    if [ -d "$dest_dir" ]; then
        rm -rf "$dest_dir"
    fi
    if ! git clone --depth 1 -b "$branch" "$repo_url" "$dest_dir"; then
        echo "[ERROR] Failed to clone $repo_url" >&2
        exit 1
    fi
}

# 添加配置到指定文件
add_config() {
    local config_content=$1
    config_contents="$config_contents$config_content"
}

# 进入 friendlywrt 目录一次
cd friendlywrt || { echo "[ERROR] Failed to enter friendlywrt directory"; exit 1; }

# 初始化配置内容变量
config_contents=""

# {{ Add common utils
add_config "
CONFIG_PACKAGE_nano=y
CONFIG_PACKAGE_lm-sensors=y
CONFIG_PACKAGE_smartmontools=y
"
# }}

# {{ Add luci-app-diskman
mkdir -p package/luci-app-diskman
download_file https://raw.githubusercontent.com/lisaac/luci-app-diskman/master/applications/luci-app-diskman/Makefile.old package/luci-app-diskman/Makefile
add_config "
CONFIG_PACKAGE_luci-app-diskman=y
CONFIG_PACKAGE_luci-app-diskman_INCLUDE_btrfs_progs=y
CONFIG_PACKAGE_luci-app-diskman_INCLUDE_lsblk=y
CONFIG_PACKAGE_luci-i18n-diskman-zh-cn=y
"
# }}

# {{ Add luci-app-vlmcsd
clone_repo https://github.com/siwind/openwrt-vlmcsd.git package/vlmcsd
clone_repo https://github.com/siwind/luci-app-vlmcsd.git package/luci-app-vlmcsd
add_config "
# 启用 luci-app-vlmcsd
CONFIG_PACKAGE_vlmcsd=y
CONFIG_PACKAGE_luci-app-vlmcsd=y
CONFIG_PACKAGE_luci-i18n-vlmcsd-zh-cn=y
"
# }}

# {{ Add luci-app-openclash
clone_repo https://github.com/vernesong/OpenClash.git package/luci-app-openclash
add_config "
# 启用 luci-app-openclash
CONFIG_PACKAGE_luci-app-openclash=y
"
# }}

# {{ Add luci-app-tailscale
clone_repo https://github.com/asvow/luci-app-tailscale.git package/luci-app-tailscale main
add_config "
# 启用 luci-app-tailscale
CONFIG_PACKAGE_tailscale=y
CONFIG_PACKAGE_luci-app-tailscale=y
CONFIG_PACKAGE_luci-i18n-tailscale-zh-cn=y
"
# }}

# {{ Add luci-theme-argon
clone_repo https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
add_config "CONFIG_PACKAGE_luci-theme-argon=y"

sed -i -e 's/function init_theme/function old_init_theme/g' target/linux/rockchip/armv8/base-files/root/setup.sh
cat > /tmp/appendtext.txt <<EOL
function init_theme() {
    if uci get luci.themes.Argon >/dev/null 2>&1; then
        uci set luci.main.mediaurlbase="/luci-static/argon"
        uci commit luci
    fi
}
EOL
sed -i -e '/boardname=/r /tmp/appendtext.txt' target/linux/rockchip/armv8/base-files/root/setup.sh
# }}

# 将所有配置内容一次性写入目标文件
cd ../ && cat <<EOL >> configs/rockchip/01-nanopi
$config_contents
EOL

log "$(cat configs/rockchip/01-nanopi)"
