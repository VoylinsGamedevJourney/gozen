#!/bin/bash

# First argument is for the threads you want to use
# Second argument is for the target you want to develop for
pushd gozen-ffmpeg
./build.sh 10 target_debug
popd

rm -r src/bin/*

cp -r gozen-ffmpeg/bin/. src/bin
