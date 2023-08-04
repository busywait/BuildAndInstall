#!/usr/bin/env bash
set -ex

if [ "$1" = "--help" ] ||
    [ "$1" = "-h" ]
then
    echo "$0 [Build Config] [Thread Count]"
    echo "Builds an unpacked .AppImage folder for RMG using build tools"
    echo "installed in an Ubuntu container environment. -march=native is"
    echo "passed to the compiler to allow all features of the CPU to be"
    echo "for optimisation. "
    exit
fi

#SJM this script merges steps from RMG/.github/workflows/build.yml with
#the local build script RMG/Source/Scripts/build.sh

script_dir="$(dirname $0)"
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

#SJM Assume that the build environment is complete and up-to-date
#if RMG/squashfs-root already exists
if [ ! -d "$toplvl_dir/squashfs-root" ] 
then
    $container_cmd "$script_dir/RmgGetOrUpdateBuildTools.sh"
fi
#...to force an update remove squash-root before running this script

#SJM git commands assume that we are working inside the repo
#and so does the linuxdeploy (AppImage) command
cd "$toplvl_dir"
$container_cmd git pull

#SJM current cmake on Linux creates missing folders for us, but documentation
#advises that we should create them
mkdir -p "$build_dir" "$bin_dir"

#SJM default to native-only compiles allowing GCC to use any extension
#supported by the CPU on the build machine
export CXXFLAGS="-march=native"
export CFLAGS="-march=native"
# TODO: check which dependencies also respect these suggestions
# TODO: move the flags in to a cmake target (eg, "NativeRelease")
# TODO: get the expanded list of flags and create a SteamDeck target
# (eg SteamDeckRelease) for cross-compiles

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

#SJM Optional: run this command outside of the ubuntu distrobox to remove 
#any of the bundled libraries that are already on the Steam Deck before 
#they are copied to the install location
mkdir "$bin_dir/../lib-not-needed" && for g in $(for f in $(find "$bin_dir/usr/lib" -type f -printf "%f\n"); do ldconfig -p  | grep -o "$f" | uniq; done); do mv "$bin_dir/usr/lib/$g" "$bin_dir/../lib-not-needed"; done

#SJM move the AppImage directory to the install path, overwrite existing
rm -rf "$install_dir.old"
mv "$install_dir" "$install_dir.old"
mv "$bin_dir" "$install_dir"

set +x
echo "RMG has been built and installed to $install_dir"
echo "Run RMG with \"$install_dir/AppRun.wrapped\""
