#!/bin/bash

# Get amount of cores/threads for compiling
read -p "Enter amount of cores/threads for compiling: " num_jobs


# Get build target
echo "Please select the build target for GoZen-ffmpeg:"
echo "1. template_debug"
echo "2. template_release"
read -p "Enter your choice (1-2): " target

case $target in
  1)
    target=template_debug
    ;;
  2)
    target=template_release
    ;;
  *)
    echo "Choosing target=template_debug as no (valid) argument was given."
    target=template_debug
    ;;
esac


# Get the target platform
echo "Please select your target platform:"
echo "1. Linux"
echo "2. Windows"
echo "3. Mac"
read -p "Enter your choice (1-3): " platform

case $platform in
  1)
    platform=linux
    ;;
  2)
    platform=windows
    pushd gozen-ffmpeg
    # We need to build FFmpeg first
    ./build_ffmpeg.sh
    popd
    ;;
  3)
    platform=macos
    ;;
  *)
    echo "Choosing platform=linuxbsd as no (valid) argument was given."
    platform=linuxbsd
    ;;
esac


pushd gozen-ffmpeg
scons -j $num_jobs destination=../src/editor/bin target=$target platform=$platform 
popd
