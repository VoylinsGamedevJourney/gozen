#!/bin/bash

rm -r gozen-ffmpeg/bin/*

# First argument: Amount of threads
# Second argument: Target you want to develop for
pushd gozen-ffmpeg
./build.sh 10 target_debug
popd

rm -r src/bin/*

cp -r gozen-ffmpeg/bin/. src/bin
