#!/usr/bin/env python3
"""
GDE GoZen FFmpeg Builder Script

This script handles the compilation of FFmpeg.
"""

import glob
import os
import shutil
import subprocess

from .build_deps import (
    build_aom,
    build_lib,
    build_mp3lame,
    build_ogg,
    build_opus,
    build_svt_av1,
    build_vorbis,
    build_vpx,
    build_x264,
    build_x265,
)
from .consts import (
    AOM_INSTALL_DIR_NAME,
    FFMPEG_SOURCE_DIR,
    MP3LAME_INSTALL_DIR_NAME,
    OGG_INSTALL_DIR_NAME,
    OPUS_INSTALL_DIR_NAME,
    SVT_AV1_INSTALL_DIR_NAME,
    VORBIS_INSTALL_DIR_NAME,
    VPX_INSTALL_DIR_NAME,
    X264_INSTALL_DIR_NAME,
    X265_INSTALL_DIR_NAME,
    get_ffmpeg_install_dir,
)
from .download_deps import download_ffmpeg_deps
from .utils import (
    CURR_PLATFORM,
    CROSS_SYSROOT,
    clear_dir,
    convert_to_msys2_path,
    run_command,
)

FFMPEG_DISABLED_MODULES = [
    "--disable-avdevice",
    "--disable-postproc",
    "--disable-avfilter",
    "--disable-sndio",
    "--disable-doc",
    "--disable-programs",
    "--disable-htmlpages",
    "--disable-manpages",
    "--disable-podpages",
    "--disable-txtpages",
]


def compile_ffmpeg(platform: str, arch: str, threads: int):
    if os.path.exists(f"{FFMPEG_SOURCE_DIR}/ffbuild/config.mak"):
        print("Cleaning FFmpeg...", flush=True)

        run_command(
            ["make", "distclean"],
            cwd=FFMPEG_SOURCE_DIR,
            use_msys2=CURR_PLATFORM == "windows",
        )
        clear_dir(get_ffmpeg_install_dir(platform))

    env: dict[str, str] = {} if CURR_PLATFORM == "windows" else dict(os.environ)

    print("Downloading FFmpeg dependencies...")
    download_ffmpeg_deps()

    print("Building FFmpeg dependencies...")
    build_x264(platform, threads, env)
    build_x265(platform, threads, env)
    build_aom(platform, threads, env)
    build_svt_av1(platform, threads, env)
    build_vpx(platform, threads, env)
    build_opus(platform, threads, env)
    build_mp3lame(platform, threads, env)
    build_ogg(platform, threads, env)
    build_vorbis(platform, threads, env)

    if platform == "linux":
        build_ffmpeg_linux(arch, threads, env)
        copy_lib_files_linux(arch)
        return

    if platform == "windows":
        build_ffmpeg_windows(arch, threads, env)
        copy_lib_files_windows(arch)
        return
    
    raise ValueError(f"Platform not supported for compiling ffmpeg: {platform}")


def build_ffmpeg_linux(arch: str, threads: int, env: dict[str, str]):
    ffmpeg_install_dir = get_ffmpeg_install_dir("linux")
    x264_pc_dir = ffmpeg_install_dir / X264_INSTALL_DIR_NAME / "lib" / "pkgconfig"
    x265_pc_dir = ffmpeg_install_dir / X265_INSTALL_DIR_NAME / "lib" / "pkgconfig"
    aom_pc_dir = (
        ffmpeg_install_dir
        / AOM_INSTALL_DIR_NAME
        / ("lib64" if arch == "x86_64" else "lib")
        / "pkgconfig"
    )
    svt_av1_pc_dir = (
        ffmpeg_install_dir
        / SVT_AV1_INSTALL_DIR_NAME
        / ("lib64" if arch == "x86_64" else "lib")
        / "pkgconfig"
    )
    vpx_pc_dir = ffmpeg_install_dir / VPX_INSTALL_DIR_NAME / "lib" / "pkgconfig"
    opus_pc_dir = ffmpeg_install_dir / OPUS_INSTALL_DIR_NAME / "lib" / "pkgconfig"
    ogg_pc_dir = ffmpeg_install_dir / OGG_INSTALL_DIR_NAME / "lib" / "pkgconfig"
    vorbis_pc_dir = ffmpeg_install_dir / VORBIS_INSTALL_DIR_NAME / "lib" / "pkgconfig"
    mp3lame_include_dir = ffmpeg_install_dir / MP3LAME_INSTALL_DIR_NAME / "include"
    mp3lame_lib_dir = ffmpeg_install_dir / MP3LAME_INSTALL_DIR_NAME / "lib"
    mp3lame_pc_dir = mp3lame_lib_dir / "pkgconfig"

    pc_paths = os.environ.get("PKG_CONFIG_PATH")
    env = {
        **env,
        "PKG_CONFIG_PATH": ":".join(
            [
                convert_to_msys2_path(x264_pc_dir),
                convert_to_msys2_path(x265_pc_dir),
                convert_to_msys2_path(aom_pc_dir),
                convert_to_msys2_path(svt_av1_pc_dir),
                convert_to_msys2_path(vpx_pc_dir),
                convert_to_msys2_path(opus_pc_dir),
                convert_to_msys2_path(ogg_pc_dir),
                convert_to_msys2_path(vorbis_pc_dir),
                convert_to_msys2_path(mp3lame_pc_dir),
            ]
        )
        + ((":" + pc_paths) if pc_paths else ""),
    }

    cmd = [
        "./configure",
        f"--prefix={ffmpeg_install_dir}",
        "--enable-shared",
        "--enable-gpl",
        "--enable-version3",
        "--enable-pthreads",
        f"--arch={arch}",
        "--target-os=linux",
        "--enable-pic",
        "--extra-cflags=-fPIC",
        "--extra-ldflags=-fPIC",
        "--pkg-config-flags=--static",
        # FFmpeg doesn't use pkgconfig to find mp3lame (have to manually specify include and lib paths)
        f"--extra-cflags=-I{convert_to_msys2_path(mp3lame_include_dir)}",
        f"--extra-ldflags=-L{convert_to_msys2_path(mp3lame_lib_dir)}",
        # Enable codecs
        "--enable-libx264",
        "--enable-libx265",
        "--enable-libaom",
        "--enable-libvpx",
        "--enable-libmp3lame",
        "--enable-libopus",
        "--enable-libvorbis",
        "--enable-libsvtav1",
    ]
    cmd += FFMPEG_DISABLED_MODULES

    build_lib(
        "FFmpeg",
        build_dir=FFMPEG_SOURCE_DIR,
        configure_cmd=cmd,
        threads=threads,
        env=env,
        use_msys2=False,
    )


def build_ffmpeg_windows(arch: str, threads: int, env: dict[str, str]):
    ffmpeg_install_dir = get_ffmpeg_install_dir("windows")
    x264_pc_dir = ffmpeg_install_dir / X264_INSTALL_DIR_NAME / "lib" / "pkgconfig"
    x265_pc_dir = ffmpeg_install_dir / X265_INSTALL_DIR_NAME / "lib" / "pkgconfig"
    aom_pc_dir = ffmpeg_install_dir / AOM_INSTALL_DIR_NAME / "lib" / "pkgconfig"
    svt_av1_pc_dir = ffmpeg_install_dir / SVT_AV1_INSTALL_DIR_NAME / "lib" / "pkgconfig"
    vpx_pc_dir = ffmpeg_install_dir / VPX_INSTALL_DIR_NAME / "lib" / "pkgconfig"
    opus_pc_dir = ffmpeg_install_dir / OPUS_INSTALL_DIR_NAME / "lib" / "pkgconfig"
    ogg_pc_dir = ffmpeg_install_dir / OGG_INSTALL_DIR_NAME / "lib" / "pkgconfig"
    vorbis_pc_dir = ffmpeg_install_dir / VORBIS_INSTALL_DIR_NAME / "lib" / "pkgconfig"
    mp3lame_include_dir = ffmpeg_install_dir / MP3LAME_INSTALL_DIR_NAME / "include"
    mp3lame_lib_dir = ffmpeg_install_dir / MP3LAME_INSTALL_DIR_NAME / "lib"
    mp3lame_pc_dir = mp3lame_lib_dir / "pkgconfig"

    env = env or {}
    env["PKG_CONFIG_PATH"] = ":".join(
        [
            convert_to_msys2_path(x264_pc_dir),
            convert_to_msys2_path(x265_pc_dir),
            convert_to_msys2_path(aom_pc_dir),
            convert_to_msys2_path(svt_av1_pc_dir),
            convert_to_msys2_path(vpx_pc_dir),
            convert_to_msys2_path(opus_pc_dir),
            convert_to_msys2_path(ogg_pc_dir),
            convert_to_msys2_path(vorbis_pc_dir),
            convert_to_msys2_path(mp3lame_pc_dir),
        ]
    )
    if CURR_PLATFORM != "windows":
        env["PKG_CONFIG_PATH"] = env["PKG_CONFIG_PATH"] + (
            (":" + os.environ["PKG_CONFIG_PATH"])
            if os.environ.get("PKG_CONFIG_PATH")
            else ""
        )
    else:
        # In msys2, os.environ.get("PKG_CONFIG_PATH") will return ';' separated windows style paths (we don't want that)
        # Also, $PKG_CONFIG_PATH will NOT exist if running in cmd or powershell, so we cannot get it from os.environ
        env["PKG_CONFIG_PATH"] += (
            ":" + "$PKG_CONFIG_PATH"  # will expand automatically in use_msys2=True mode
        )

    print("PKG_CONFIG_PATH set to:", env["PKG_CONFIG_PATH"], flush=True)

    cmd = [
        "./configure",
        f"--prefix={convert_to_msys2_path(ffmpeg_install_dir)}",
        "--enable-static",
        "--enable-gpl",
        "--enable-version3",
        f"--arch={arch}",
        "--target-os=mingw32",
        "--extra-libs=-lpthread",
        # Tell pkgconfig to use static libs
        "--pkg-config-flags=--static",
        # FFmpeg doesn't use pkgconfig to find mp3lame (have to manually specify include and lib paths)
        f"--extra-cflags=-I{convert_to_msys2_path(mp3lame_include_dir)}",
        f"--extra-ldflags=-L{convert_to_msys2_path(mp3lame_lib_dir)}",
        # Enable codecs
        "--enable-libx264",
        "--enable-libx265",
        "--enable-libaom",
        "--enable-libvpx",
        "--enable-libmp3lame",
        "--enable-libopus",
        "--enable-libvorbis",
        "--enable-libsvtav1",
    ]
    cmd += FFMPEG_DISABLED_MODULES

    if CURR_PLATFORM != "windows":
        cmd += [
            "--enable-cross-compile",
            "--cross-prefix=x86_64-w64-mingw32-",
            "--pkg-config=pkg-config",  # `x86_64-w64-mingw32-pkg-config` prepends `/usr/x86_64-w64-mingw32/sys-root/mingw/` to all paths
            "--extra-cflags=-DWINICONV_CONST",  # see: https://github.com/win-iconv/win-iconv/issues/25
        ]

    build_lib(
        "FFmpeg",
        build_dir=FFMPEG_SOURCE_DIR,
        configure_cmd=cmd,
        threads=threads,
        env=env,
        use_msys2=CURR_PLATFORM == "windows",
    )


def copy_lib_files_linux(arch: str):
    path = f"bin/linux_{arch}"
    os.makedirs(path, exist_ok=True)

    print(f"Copying lib files to {path} ...")

    for file in glob.glob("ffmpeg/bin_linux/lib/*.so.*"):
        if file.count(".") == 2:
            shutil.copy2(file, path)

    print("Finding and copying required system .so dependencies ...", flush=True)

    def copy_dependencies(binary_path: str):
        try:
            output = subprocess.check_output(["ldd", binary_path], text=True)
            for line in output.splitlines():
                if "=>" not in line:
                    continue
                parts = line.strip().split("=>")
                if len(parts) < 2:
                    continue
                lib_path = parts[1].split("(")[0].strip()
                if not os.path.isfile(lib_path):
                    continue

                print(lib_path)

                if any(
                    lib_path.endswith(name)
                    for name in (
                        "libc.so.6",
                        "libm.so.6",
                        "libpthread.so.0",
                        "libdl.so.2",
                        "librt.so.1",
                        "ld-linux-x86-64.so.2",
                    )
                ):
                    continue

                lib_name = os.path.basename(lib_path)
                dest_path = os.path.join(path, lib_name)

                if os.path.abspath(lib_path) == os.path.abspath(dest_path):
                    continue  # Avoid SameFileError

                shutil.copy2(lib_path, path)
        except subprocess.CalledProcessError as e:
            print(f"Failed to run ldd on {binary_path}: {e}")

    # TODO: Make this work without manually adding version number
    binaries = [
        f"{path}/libavcodec.so.60",
        f"{path}/libavformat.so.60",
        f"{path}/libavutil.so.58",
        f"{path}/libswscale.so.7",
        f"{path}/libswresample.so.4",
        f"bin/linux_{arch}/libgozen.linux.template_debug.{arch}.so",
    ]

    # TODO: Make this not copy all libraries, only needed ones (x264, x265)
    for binary in binaries:
        if os.path.exists(binary):
            copy_dependencies(binary)
        else:
            print(f"Warning: {binary} not found, skipping...")

    print("Copying files for Linux finished!", flush=True)


def copy_lib_files_windows(arch: str):
    path = f"bin/windows_{arch}"
    dll_dir = CROSS_SYSROOT / "bin"
    extra_libs = [
        "libwinpthread-1.dll",
        "libgcc_s_seh-1.dll",
    ]

    print(f"Copying lib files to {path} ...")
    os.makedirs(path, exist_ok=True)

    for file in glob.glob("ffmpeg/bin_windows/bin/*.dll") + [
        dll_dir / dll for dll in extra_libs
    ]:
        shutil.copy2(file, path)

    print("Copying files for Windows finished!", flush=True)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", type=str, default="linux")
    parser.add_argument("--arch", type=str, default="x86_64")
    parser.add_argument("--threads", type=int, default=4)
    args = parser.parse_args()

    compile_ffmpeg(args.platform, args.arch, args.threads)
