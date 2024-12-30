# Compiling libraries for GoZen

## Linux only ... unless ...

Right now the compiling only works on Linux, unless you can use WSL on Windows, but for that you will need to rely on your own knowledge as I'm not a Windows user and I have no clue how that stuff works. Feel free to ask for advice in the Discord server or to contribute to make compiling possible on Windows.

## Let's start!

To compile the GDExtension (be certain that you initialized all the submodules first), run ffmpeg.sh and do a clean up just in case, you can do this easily by going in this folder and running `./ffmpeg.sh 0`. After that you can compile for Linux with `./ffmpeg.sh 1` or for Windows with `./ffmpeg.sh 2`. Support for MacOS and Web may come in the future but is not on my priority list for now.

## After FFmpeg

After you got the FFmpeg files compiled, you can run scons. If you want the Linux version and you are on Linux, just run `scons -j10 dev_build=yes`. The dev_build option is needed for the debug version, remove it for release versions. For Windows you just add `platform=windows`.

## Missing libraries

You may need x264 and x265 installed on your system before compiling. When compiling for Windows on Linux, you will need following packages from the AUR or your package manager:
- mingw-w64-x264;
- mingw-w64-x265;
- mingw-w64-pkg-config;

For enabling more libraries such as webm, you will need to add those to the ffmpeg.sh script and install those libraries on your machine first, for Windows install the mingw equivalent options.

