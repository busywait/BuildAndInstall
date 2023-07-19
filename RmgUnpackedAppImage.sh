#!/usr/bin/env bash
set -ex

#SJM merging steps from 
#https://github.com/Rosalie241/RMG/blob/master/.github/workflows/build.yml
#in to the local build script

script_dir="$(dirname "$0")"
script_dir="$(realpath "$script_dir")"
toplvl_dir="$(realpath "$script_dir/../RMG/")"
build_config="${1:-Release}"
export src_dir="$toplvl_dir"
export build_dir="$toplvl_dir/Build/AppImage"
export bin_dir="$toplvl_dir/Bin/AppImage"
packaging_tools_dir="$toplvl_dir/Package/AppImage"
install_dir="/home/deck/Applications/RMG-install"
container_cmd="distrobox-enter ubuntu -- "
threads="${2:-$(nproc)}"

if [ "$1" = "--help" ] ||
    [ "$1" = "-h" ]
then
    echo "$0 [Build Config] [Thread Count]"
    exit
fi

#SJM git commands assume that we are working inside the repo
#and so does the linuxdeploy (AppImage) script
cd "$toplvl_dir"
$container_cmd git pull

#SJM current cmake on Linux does this for us anyway
mkdir -p "$build_dir" "$bin_dir"

#SJM play with native-only compiles allowing GCC to use any extension
#supported by the CPU on the build machine
export CXXFLAGS="-march=native"
export CFLAGS="-march=native"

#SJM I'm not sure what this is for but the github build action does it
export GITHUB_ENV="$toplvl_dir/git-ver.txt"
$container_cmd echo "GIT_REVISION=$(git describe --tags --always)" >> $GITHUB_ENV

$container_cmd cmake --fresh -S "$toplvl_dir" -B "$build_dir" -DCMAKE_BUILD_TYPE="$build_config" -DPORTABLE_INSTALL="OFF" -DUPDATER=ON -DAPPIMAGE_UPDATER=ON -DCMAKE_INSTALL_PREFIX="/usr" -G "Ninja"
#The local build command line
#cmake -S "$toplvl_dir" -B "$build_dir" -DCMAKE_BUILD_TYPE="$build_config" -DPORTABLE_INSTALL=ON -G "Ninja"

$container_cmd cmake --build "$build_dir" --parallel "$threads" -v
$container_cmd cmake --install "$build_dir" --prefix="$bin_dir/usr"
#SJM local install command line
#cmake --install "$build_dir" --prefix="$toplvl_dir"

#if [[ $(uname -s) = *MINGW64* ]]
#then
#    cmake --build "$build_dir" --target=bundle_dependencies
#fi

#SJM This will modify the build binaries as required for the AppImage 
#and copy in library dependancies.
$container_cmd "$toplvl_dir/Package/AppImage/Create.sh --folder-only"
#SJM Modified from Package/AppImage/Create.sh to avoid creating the 
#compressed AppImage file
#$container_cmd "$script_dir/_buildRmgAppImageFolder.sh"

#SJM Optional: run outside of the ubuntu distrobox to remove any of the 
#bundled libraries that are already on the Steam Deck before they are 
#copied to the install location
mkdir "$bin_dir/../lib-not-needed" && for g in $(for f in $(find "$bin_dir/usr/lib" -type f -printf "%f\n"); do ldconfig -p  | grep -o "$f" | uniq; done); do mv "$bin_dir/usr/lib/$g" "$bin_dir/../lib-not-needed"; done

#_SJM copy everything in the AppImage directory
rm -rf "$install_dir"
cp -r "$bin_dir" "$install_dir"

set +x
echo RmgUpackedAppImage Done
