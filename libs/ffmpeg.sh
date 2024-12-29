#!/bin/bash
# This only works on Linux systems!


function compile_linux() {
	echo "Compiling FFmpeg for Linux ..."

	if [ ! -d "./bin/linux" ]; then
		mkdir "./bin/linux"
	fi

	export PKG_CONFIG_PATH=/usr/lib/pkgconfig

	cd ffmpeg
	ffmpeg_args=$(cat <<-END
		 --enable-shared --quiet --disable-postproc
		 --disable-avfilter --disable-sndio --disable-programs
		 --disable-ffprobe --disable-doc --disable-htmlpages
		 --disable-manpages --disable-podpages --disable-txtpages
		 --arch=x86_64 --disable-ffplay --disable-ffmpeg
		 --enable-gpl --enable-version3 --enable-lto
		 --enable-libx264 --enable-libx265 --enable-libwebp
		 --enable-libopus --enable-libpulse --enable-libvorbis
		 --extra-cflags="-fPIC"
		 --extra-ldflags="-fpic" --target-os=linux
	END
	)

    ./configure --prefix=./bin $ffmpeg_args

    make -j 9
    make -j 9 install

	cp bin/lib/*.so* ../bin/linux
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
	ffmpeg_args=$(cat <<-END
		--enable-shared --quiet --disable-postproc --disable-avfilter
		--disable-sndio --disable-programs --disable-ffmpeg --disable-ffplay
        --disable-ffprobe --disable-doc --disable-htmlpages --disable-manpages
		--disable-podpages --disable-txtpages --arch=x86_64 --enable-gpl
		--enable-version3 --enable-lto --enable-libx264 --enable-libx265
		--extra-cflags="-fPIC" --extra-ldflags="-fpic" --extra-libs=-lpthread
		--cross-prefix=x86_64-w64-mingw32- --target-os=mingw32
		--enable-cross-compile
	END
	)
	
	PATH="/opt/bin:$PATH"
	./configure --prefix=./bin $ffmpeg_args

    make -j 4
    make -j 4 install

    cp bin/lib/*.a ../bin/windows
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
