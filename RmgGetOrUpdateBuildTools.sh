#!/usr/bin/env bash
set -ex

script_dir="$(realpath $(dirname "$0"))"
toplvl_dir="$(realpath "$script_dir/../RMG/")"

# A script that needs to be run once to get the build and linuxdeploy tools
# that are used to create AppImages. The .github/workflows/build.yml does 
# some of this setup in the Install Packages step on the build server,
# but this must be run before building an appimage on a local machine.

# From .gihub/workflows/build.yml
sudo apt-get purge grub\* --yes --allow-remove-essential
sudo add-apt-repository ppa:okirby/qt6-backports --yes
sudo apt-get -qq update
sudo apt-get upgrade
sudo apt-get -y install cmake ninja-build libhidapi-dev libsamplerate0-dev libspeex-dev libminizip-dev libsdl2-dev libfreetype6-dev libgl1-mesa-dev libglu1-mesa-dev pkg-config zlib1g-dev binutils-dev libspeexdsp-dev qt6-base-dev libqt6svg6-dev build-essential nasm git zip appstream

# From Package/AppImage/Create.sh
packaging_tools_dir="$(toplvl_dir)/Package/AppImage"
curl -L https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage -o "$packaging_tools_dir/linuxdeploy-x86_64.AppImage"
chmod +x "$packaging_tools_dir/linuxdeploy-x86_64.AppImage"
curl -L https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage -o "$packaging_tools_dir/linuxdeploy-plugin-qt-x86_64.AppImage"
chmod +x "$packaging_tools_dir/linuxdeploy-plugin-qt-x86_64.AppImage"

# To mirror .github/workflows/build.yml this script will always unpack
# the linuxdeploy tools to $toplvl_dir/squashfs
pushd "$toplvl_dir"
"$packaging_tools_dir/linuxdeploy-plugin-qt-x86_64.AppImage" --appimage-extract
"$packaging_tools_dir/linuxdeploy-x86_64.AppImage" --appimage-extract
popd

# delete appimages
rm "$script_dir/linuxdeploy-x86_64.AppImage" \
    "$script_dir/linuxdeploy-plugin-qt-x86_64.AppImage"

