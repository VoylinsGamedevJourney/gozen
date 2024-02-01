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
  pushd src/translations/POT
  git pull
  ./generate_mo_files.sh
  popd
}


function compile_gdextension() {
  echo "Updating godot-cpp"
  pushd src/bin/gde_ffmpeg/godot-cpp
  git pull
  popd

  echo "GDExtension compiling"
  echo "Select target platform:"
  echo "1. Linux"
  echo "2. Windows (not-supported yet)"
  echo "3. Mac (not-supported yet)"
  read -p "> " platform
  case $platform in
    1)
      platform=linux
      ;;
    2)
      platform=windows
      #echo "Windows export not supported yet!"
      #exit 1
      ;;
    3)
      platform=macos
      echo "MacOS export not supported yet!"
      exit 1
      ;;
    *)
      echo "Choosing platform=linuxbsd as no (valid) argument was given."
      platform=linuxbsd
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
  echo "Enter amount of cores/thread for compiling:"
  read -p "> " num_jobs
  pushd src/bin/gde_ffmpeg/
  scons -j $num_jobs target=$target platform=$platform
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


