#!/bin/bash
# This only works on Linux systems!


function compile_linux() {
	echo "Compiling FFmpeg for Linux ..."

	if [ ! -d "./bin/linux" ]; then
		mkdir "./bin/linux"
	fi

	export PKG_CONFIG_PATH=/usr/lib/pkgconfig

	cd ffmpeg
	./configure --prefix=./bin --enable-shared \
		--enable-gpl --enable-version3 \
		--arch=x86_64 --target-os=linux \
		--quiet \
		--enable-pic \
		\
		--extra-cflags="-fPIC" --extra-ldflags="-fPIC" \
		\
		--disable-postproc --disable-avfilter --disable-sndio \
		--disable-doc --disable-programs --disable-ffprobe \
		--disable-htmlpages --disable-manpages --disable-podpages \
		--disable-txtpages --disable-ffplay --disable-ffmpeg \
		\
		--enable-libx264 --enable-libx265 \

	make -j $(nproc)
	make install

	cp bin/lib/*.so ../bin/linux
	cp /usr/lib/libx26*.so ../bin/linux

	echo "Compiling FFmpeg for Linux complete"
}


function compile_windows() {
	echo "Compiling FFmpeg for Windows ..."

	export PKG_CONFIG_LIBDIR="/usr/x86_64-w64-mingw32/lib/pkgconfig"
	export PKG_CONFIG_PATH="/usr/x86_64-w64-mingw32/lib/pkgconfig"

	if [ ! -d "./bin/windows" ]; then
		mkdir "./bin/windows"
	fi

	cd ffmpeg
	PATH="/opt/bin:$PATH"
	./configure --prefix=./bin --enable-shared \
		--enable-gpl --enable-version3 \
		--arch=x86_64 --target-os=mingw32 --enable-cross-compile \
		--cross-prefix=x86_64-w64-mingw32- \
		--quiet \
		--extra-libs=-lpthread \
		--extra-cflags="-fPIC" --extra-ldflags="-fpic" \
		\
		--disable-postproc --disable-avfilter --disable-sndio \
		--disable-doc --disable-programs --disable-ffprobe \
		--disable-htmlpages --disable-manpages --disable-podpages \
		--disable-txtpages --disable-ffplay --disable-ffmpeg \
		\
		--enable-libx264 --enable-libx265

	make -j $(nproc)
	make install

	cp bin/bin/*.dll ../bin/windows
	cp /usr/x86_64-w64-mingw32/bin/libx26*.dll ../bin/windows

	echo "Compiling FFmpeg for Windows complete"
}

if [ $# -eq 0 ]; then
	# Interactive mode
	echo "Please select an option:"
	echo "1: Compile for Linux; (Default)"
	echo "2: Compile for Windows;"
	echo "0: Clean FFmpeg;"

	read -p "Enter your choice: " choice
	echo ""
else
	# Argument-based mode
	choice=$1
fi

case $choice in
	2) # Windows
		compile_windows;;
	0) # Cleanup FFmpeg
		echo "Cleaning FFmpeg"
		cd ffmpeg
		make distclean
		rm -rf bin
		echo "FFmpeg repo is cleaned up!";;
	*) # Linux
		compile_linux;;
esac

echo ""
