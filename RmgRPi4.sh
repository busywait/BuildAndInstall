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
build_arch=ARM
export src_dir="$toplvl_dir"
export build_dir="$toplvl_dir/Build/$build_arch/$build_config"
export bin_dir="$toplvl_dir/Bin/$build_arch/$build_config"
install_dir="$(realpath ~/RMG-install)"
threads=2

cmake_strip_args=" --strip "
# Don't strip debug builds (configurations starting with Deb)
if [[ $build_config =~ ^Deb+ ]]
then
   cmake_strip_args=" "
fi

#SJM git commands assume that we are working inside the repo
#and so does the linuxdeploy (AppImage) command
cd "$toplvl_dir"

#SJM current cmake on Linux creates missing folders for us, but documentation
#advises that we should create them
mkdir -p "$build_dir" "$bin_dir"

#SJM default to native-only compiles allowing GCC to use any extension
#supported by the CPU on the build machine
export CXXFLAGS="-march=native"
export CFLAGS="-march=native"
# TODO: check which dependencies also respect these suggestions
# TODO: move the flags in to a cmake configuration (eg, "NativeRelease")
# TODO: get the expanded list of flags and create a SteamDeck target
# (eg SteamDeckRelease) for cross-compiles

#SJM I'm not sure what this is for but the github build action does it
export GITHUB_ENV="$toplvl_dir/git-ver.txt"
echo "GIT_REVISION=$(git describe --tags --always)" >> $GITHUB_ENV

# The AppImage is PORTABLE_INSTALL=OFF
# When PORTABLE_INSTALL=ON the CMAKE_INSTALL_PREFIX will be overwritten to an empty string in RMG/CMakeLists.txt
cmake --fresh -S "$toplvl_dir" -B "$build_dir" -DCMAKE_BUILD_TYPE="$build_config" -DPORTABLE_INSTALL="ON" -DUPDATER=ON -DAPPIMAGE_UPDATER=ON -DRPI4=ON -G "Ninja"
#The local build command line
#cmake -S "$toplvl_dir" -B "$build_dir" -DCMAKE_BUILD_TYPE="$build_config" -DPORTABLE_INSTALL=ON -G "Ninja"

cmake --build "$build_dir" --parallel "$threads" -v
# a --prefix given for --install here will be prepended to any CMAKE_INSTALL_PREFIX given above
cmake --install "$build_dir" $cmake_strip_args --prefix="$bin_dir"

#if [[ $(uname -s) = *MINGW64* ]]
#then
#    cmake --build "$build_dir" --target=bundle_dependencies
#fi

#SJM move the AppImage directory to the install path, overwrite existing
rm -rf "$install_dir.old"
if [ -d "$install_dir" ]
then
    mv "$install_dir" "$install_dir.old"
fi
mv "$bin_dir" "$install_dir"

set +x
echo "RMG has been built and installed to $install_dir"
echo "Run RMG with \"$install_dir/RMG\""
