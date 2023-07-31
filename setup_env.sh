#!/bin/bash -eu

# toolchain
sudo apt update
sudo apt install git unzip
curl -fsSL https://raw.githubusercontent.com/friendlyarm/build-env-on-ubuntu-bionic/master/install.sh | sudo bash

export PATH=/opt/FriendlyARM/toolchain/11.3-aarch64/bin:$PATH

# tools
git clone https://github.com/osm0sis/Android-Image-Kitchen --single-branch -b AIK-Linux --depth 1
curl -LO https://github.com/libxzr/vbmeta-disable-verification/releases/download/v1.0/vbmeta-disable-verification.zip
unzip -p vbmeta-disable-verification.zip x86_64/vbmeta_disable_verification > vbmeta_disable_verification
chmod +x vbmeta_disable_verification

git clone https://github.com/friendlyarm/kernel-rockchip --single-branch -b nanopi5-v5.10.y_opt --depth 1
cd kernel-rockchip

# get Android .config
make CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 nanopi5_android_defconfig
mv .config android_config
make CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 mrproper

# get Linux .config
make CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 nanopi5_linux_defconfig
mv .config linux_config
make CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 mrproper

# merge config
ruby ../merge_config.rb linux_config android_config > /dev/null

# temp fix for link error
sed -i 's/CONFIG_BCMDHD=y/CONFIG_BCMDHD=n/' .config
sed -i 's/^\(CONFIG_BCMDHD_\)/# \1/g' .config

# change all module to builtin
sed -i 's/=m$/=y/g' .config

# customize config
make CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 menuconfig

# build kernel
make CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 nanopi5-images -j$(nproc)