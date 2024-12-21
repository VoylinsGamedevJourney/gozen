#!/bin/bash
# This only works on Linux systems!


function compile_linux() {
	echo "Compiling FFmpeg for Linux ..."

	if [ ! -d "./bin/linux" ]; then
		mkdir "./bin/linux"
	fi

	cd ffmpeg
	ffmpeg_args=$(cat <<-END
		 --enable-shared --quiet --disable-postproc
		 --disable-avfilter --disable-sndio --disable-programs
		 --disable-ffprobe --disable-doc --disable-htmlpages
		 --disable-manpages --disable-podpages --disable-txtpages
		 --arch=x86_64 --disable-ffplay --disable-ffmpeg
		 --enable-gpl --enable-version3 --enable-lto --enable-libaom
		 --enable-nvdec --enable-nvenc --enable-libx264 --enable-libx265
		 --enable-libopus --enable-libpulse --enable-opencl
		 --enable-libtheora --enable-libvpx --enable-libvpl
		 --enable-libass --enable-libdav1d --enable-libdrm
		 --enable-libsoxr --enable-vulkan --enable-opengl
		 --enable-libmp3lame --enable-libvorbis --enable-libxvid
		 --enable-librav1e --enable-libsvtav1 --enable-libxml2
		 --enable-libopenmpt --enable-cuda-llvm
		 --extra-cflags="-fPIC" --extra-ldflags="-fpic"
		 --target-os=linux
	END
	)

    ./configure --prefix=./bin $ffmpeg_args

    make -j 4
    make -j 4 install

	cp bin/lib/*.so* ../bin/linux
	echo "Compiling FFmpeg for Linux complete"
}


function compile_windows() {
	echo "Compiling FFmpeg for Windows ..."

	if [ ! -d "./bin/windows" ]; then
		mkdir "./bin/windows"
	fi

	cd ffmpeg
	ffmpeg_args=$(cat <<-END
		--enable-shared --quiet --disable-postproc --disable-avfilter
		--disable-sndio --disable-programs --disable-ffmpeg --disable-ffplay
        --disable-ffprobe --disable-doc --disable-htmlpages --disable-manpages
		--disable-podpages --disable-txtpages --arch=x86_64 --enable-gpl
		--enable-version3 --enable-lto --cross-prefix=x86_64-w64-mingw32-
		--target-os=mingw32 --enable-cross-compile --extra-ldflags="-static"
	END
	)
	
	PATH="/opt/bin:$PATH"
	./configure --prefix=./bin $ffmpeg_args

    make -j 4
    make -j 4 install

    cp bin/bin/*.dll ../bin/windows
	echo "Compiling FFmpeg for Windows complete"
}


echo "Please select an option:"
echo "1: Compile for Linux; (Default)"
echo "2: Compile for Windows;"
echo "0: Clean FFmpeg;"

read -p "Enter your choice: " choice
echo ""

case $choice in
	2) # Windows
		compile_windows;;
	0) # Cleanup FFmpeg
		cd ffmpeg
		make distclean
		echo "FFmpeg repo is cleaned up!";;
	*) # Linux
		compile_linux;;
esac

echo ""
