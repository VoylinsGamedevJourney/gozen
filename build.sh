#!/bin/bash

echo "-= GoZen Builder =-"
echo "1. Build GoZen [full]"
echo "2. Build GoZen [light]"
echo "3. Generate localization"
echo "4. Compile GDExtension"
read -p "> " choice


function build_gozen_full() {
  generate_localization
  compile_gdextension
}


function build_gozen_light() {
  generate_localization
  compile_gdextension
}


function generate_localization() {
  pushd src/translations/gozen-translations
  git pull
  ./generate_mo_files.sh
  popd
}


function compile_gdextension() {
  echo "Updating godot-cpp"
  pushd src/bin/gde_ffmpeg/godot-cpp
  git pull
  popd

  local scons_extra_args=""

  echo "GDExtension compiling"

  echo "Enter amount of cores/thread for compiling:"
  read -p "> " num_jobs

  echo "Select target platform:"
  echo "1. Linux"
  echo "2. Windows (Msys2)"
  echo "3. Mac (not-supported yet)"
  read -p "> " platform
  case $platform in
    1)
      platform=linux
      ;;
    2)
      platform=windows
      scons_extra_args="use_mingw=yes"
      echo "Build FFmpeg? (y/N)"
        read -p "> " ffmpeg
        case $ffmpeg in
          y)
            pushd src/bin/gde_ffmpeg/
            ./build-ffmpeg.sh $platform $num_jobs || { echo "FFmpeg build failed"; exit 1; }
            popd
            ;;
          *)
            ;;
        esac
      ;;
    3)
      platform=macos
      echo "MacOS export not supported yet!"
      exit 1
      ;;
    *)
      echo "Choosing platform=linuxbsd as no (valid) argument was given."
      platform=linux
      ;;
  esac

  echo "Select build taget:"
  echo "1. template_debug"
  echo "2. template_release"
  read -p "> " target
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

  pushd src/bin/gde_ffmpeg/
  scons -j $num_jobs target=$target platform=$platform $scons_extra_args
  popd
}



case $choice in
  1)
    echo "Building GoZen Full"
    build_gozen_full
    ;;
  2)
    echo "Building GoZen Light"
    build_gozen_light
    ;;
  3)
    echo "Generating Localization"
    generate_localization
    ;;
  4)
    echo "Compiling GDExtension"
    compile_gdextension
    ;;
  *)
    echo "Invalid choice"
    ;;
esac


