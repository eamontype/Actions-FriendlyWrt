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

# Git稀疏克隆，只克隆指定目录到本地
function git_sparse_clone() {
    # 参数检查
    if [ "$#" -lt 3 ]; then
        echo "Usage: git_sparse_clone <branch> <repository_url> <dir1> [<dir2> ...]"
        return 1
    fi

    local branch repourl repodir target_dirs
    branch="$1"
    repourl="$2"
    shift 2
    target_dirs=("$@")  # 保存所有目标目录

    # 克隆仓库
    git clone --depth=1 -b "$branch" --single-branch --filter=blob:none --sparse "$repourl" || {
        echo "Error: Failed to clone repository."
        return 1
    }

    # 提取仓库目录名
    repodir=$(basename "$repourl" .git)
    if [ ! -d "$repodir" ]; then
        echo "Error: Cloned repository directory '$repodir' does not exist."
        return 1
    fi

    # 进入仓库目录
    cd "$repodir" || return 1

    # 设置稀疏检出目标
    git sparse-checkout init || {
        echo "Error: Failed to initialize sparse-checkout."
        return 1
    }
    git sparse-checkout set "${target_dirs[@]}" || {
        echo "Error: Failed to sparse-checkout specified directories."
        return 1
    }

    # 移动指定目录到上级目录
    for dir in "${target_dirs[@]}"; do
        if [ -d "$dir" ]; then
            mv -f "$dir" ../package || {
                echo "Error: Failed to move directory '$dir'."
                return 1
            }
        else
            echo "Warning: Directory '$dir' does not exist."
        fi
    done

    # 返回上级目录并删除克隆的仓库
    cd .. || return 1
    rm -rf "$repodir" || {
        echo "Warning: Failed to remove temporary repository '$repodir'."
        return 1
    }

    echo "Sparse clone and directory move completed successfully."
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
CONFIG_PACKAGE_vlmcsd=y
CONFIG_PACKAGE_luci-app-vlmcsd=y
CONFIG_PACKAGE_luci-i18n-vlmcsd-zh-cn=y
"
# }}

# {{ Add luci-app-openclash
git_sparse_clone master https://github.com/vernesong/OpenClash.git luci-app-openclash
add_config "
CONFIG_PACKAGE_luci-app-openclash=y
"
# }}

# {{ Add luci-app-tailscale
clone_repo https://github.com/asvow/luci-app-tailscale.git package/luci-app-tailscale main
add_config "
CONFIG_PACKAGE_tailscale=y
CONFIG_PACKAGE_luci-app-tailscale=y
CONFIG_PACKAGE_luci-i18n-tailscale-zh-cn=y
"
# }}

# {{ Add luci-theme-argon
clone_repo https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
add_config "
CONFIG_PACKAGE_luci-theme-argon=y
"

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

log "package目录下的文件夹$(ls -d */)"
log "$(tail -n 30 configs/rockchip/01-nanopi)"
