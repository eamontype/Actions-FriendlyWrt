#!/bin/bash

sed -i -e '/CONFIG_MAKE_TOOLCHAIN=y/d' configs/rockchip/01-nanopi
sed -i -e 's/CONFIG_IB=y/# CONFIG_IB is not set/g' configs/rockchip/01-nanopi
sed -i -e 's/CONFIG_SDK=y/# CONFIG_SDK is not set/g' configs/rockchip/01-nanopi

# 创建目录，如果目录不存在
mkdir -p ./friendlywrt/files/etc/uci-defaults

cat <<EOF > ./friendlywrt/files/etc/uci-defaults/99-custom
#!/bin/sh
# 根据网卡数量配置网络
count=0
for iface in $(ls /sys/class/net | grep -v lo); do
  # 检查是否有对应的设备，并且排除无线网卡
  if [ -e /sys/class/net/$iface/device ] && [[ $iface == eth* || $iface == en* ]]; then
    count=$((count + 1))
  fi
done
if [ "$count" -eq 1 ]; then
    # 单个网卡，设置为 DHCP 模式
    uci set network.lan.proto='dhcp'
    uci commit network
elif [ "$count" -gt 1 ]; then
    # 多个网卡，保持静态 IP
    uci set network.lan.ipaddr='192.168.74.1'
    uci commit network
fi
EOF

echo "脚本已创建并设置为可执行：$(cat ./friendlywrt/files/etc/uci-defaults/99-custom)"