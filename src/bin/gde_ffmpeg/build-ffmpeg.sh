#!/bin/bash

echo "Running FFmpeg builder ..."
platform=$1
num_jobs=${2:-6}

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
gdextension_dir="$script_dir/.."

ffmpeg_source_folder="$script_dir/ffmpeg"
ffmpeg_bin_folder="$script_dir/ffmpeg-bin"

mkdir -p "$ffmpeg_bin_folder"
cd "$ffmpeg_source_folder" || exit -1
echo "Updating ffmpeg submodule ..."
git pull

config_extra_args=""
if [ "$platform" = "windows" ]; then
    export PATH="/opt/bin":$PATH
    cross_prefix="x86_64-w64-mingw32-"
    config_extra_args="--cross-prefix="$cross_prefix" --arch=x86_64 --target-os=mingw32"
fi

echo "Configuring ffmpeg ..."
./configure --prefix="$ffmpeg_bin_folder" --enable-gpl --enable-shared $config_extra_args || exit -1

echo "Building ffmpeg ..."
make -j $num_jobs || exit -1

echo "Installing ffmpeg ..."
make -j $num_jobs install || exit -1

if [ "$platform" = "windows" ]; then
    echo "Copying dlls to GDExtension dir ..."
    cp -fu $ffmpeg_bin_folder/bin/*.dll $gdextension_dir

    # Copy dlls from /mingw64/bin (Adding to 'PATH' environment variable doesn't work)
    dll_path="/mingw64/bin"
    dlls="zlib1.dll libiconv-2.dll libbz2-1.dll liblzma-5.dll libwinpthread-1.dll"
    for dll in $dlls; do
        cp -fu $dll_path/$dll $gdextension_dir
    done
fi