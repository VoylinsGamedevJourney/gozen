#!/usr/bin/env python3
"""
GDE GoZen FFmpeg Builder Script

This script handles the compilation of FFmpeg.
"""

import os
import shutil
import subprocess
from pathlib import Path
from typing import Generator

try:
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
    from .download_deps import download_ffmpeg_deps
    from .paths import (
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
        get_lib_dir,
    )
    from .utils import (
        _GOZEN_CROSS_SYSROOT,
        CURR_PLATFORM,
        clear_dir,
        convert_to_msys2_path,
        get_host_and_sysroot,
        run_command,
    )
except ImportError:
    from build_deps import (
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
    from download_deps import download_ffmpeg_deps
    from paths import (
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
        get_lib_dir,
    )
    from utils import (
        _GOZEN_CROSS_SYSROOT,
        CURR_PLATFORM,
        clear_dir,
        convert_to_msys2_path,
        get_host_and_sysroot,
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
    "--disable-network",
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
    build_x264(platform, arch, threads, env)
    build_x265(platform, arch, threads, env)
    build_aom(platform, arch, threads, env)
    build_svt_av1(platform, arch, threads, env)
    build_vpx(platform, arch, threads, env)
    build_opus(platform, arch, threads, env)
    build_mp3lame(platform, arch, threads, env)
    build_ogg(platform, arch, threads, env)
    build_vorbis(platform, arch, threads, env)

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
    x264_pc_dir = get_lib_dir(ffmpeg_install_dir / X264_INSTALL_DIR_NAME) / "pkgconfig"
    x265_pc_dir = get_lib_dir(ffmpeg_install_dir / X265_INSTALL_DIR_NAME) / "pkgconfig"
    aom_pc_dir = get_lib_dir(ffmpeg_install_dir / AOM_INSTALL_DIR_NAME) / "pkgconfig"
    svt_av1_pc_dir = (
        get_lib_dir(ffmpeg_install_dir / SVT_AV1_INSTALL_DIR_NAME) / "pkgconfig"
    )
    vpx_pc_dir = get_lib_dir(ffmpeg_install_dir / VPX_INSTALL_DIR_NAME) / "pkgconfig"
    opus_pc_dir = get_lib_dir(ffmpeg_install_dir / OPUS_INSTALL_DIR_NAME) / "pkgconfig"
    ogg_pc_dir = get_lib_dir(ffmpeg_install_dir / OGG_INSTALL_DIR_NAME) / "pkgconfig"
    vorbis_pc_dir = (
        get_lib_dir(ffmpeg_install_dir / VORBIS_INSTALL_DIR_NAME) / "pkgconfig"
    )
    mp3lame_lib_dir = get_lib_dir(ffmpeg_install_dir / MP3LAME_INSTALL_DIR_NAME)
    mp3lame_include_dir = ffmpeg_install_dir / MP3LAME_INSTALL_DIR_NAME / "include"
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
    host, _ = get_host_and_sysroot("linux", arch)

    cmd = [
        "./configure",
        f"--prefix={ffmpeg_install_dir}",
        "--enable-shared",
        "--enable-gpl",
        "--enable-version3",
        "--enable-pthreads",
        f"--arch={'aarch64' if arch == 'arm64' else arch}",
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

    if arch == "arm64":
        cmd += [
            "--enable-cross-compile",
            f"--cross-prefix={host}-",
            "--pkg-config=pkg-config",
        ]

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
    x264_pc_dir = get_lib_dir(ffmpeg_install_dir / X264_INSTALL_DIR_NAME) / "pkgconfig"
    x265_pc_dir = get_lib_dir(ffmpeg_install_dir / X265_INSTALL_DIR_NAME) / "pkgconfig"
    aom_pc_dir = get_lib_dir(ffmpeg_install_dir / AOM_INSTALL_DIR_NAME) / "pkgconfig"
    svt_av1_pc_dir = (
        get_lib_dir(ffmpeg_install_dir / SVT_AV1_INSTALL_DIR_NAME) / "pkgconfig"
    )
    vpx_pc_dir = get_lib_dir(ffmpeg_install_dir / VPX_INSTALL_DIR_NAME) / "pkgconfig"
    opus_pc_dir = get_lib_dir(ffmpeg_install_dir / OPUS_INSTALL_DIR_NAME) / "pkgconfig"
    ogg_pc_dir = get_lib_dir(ffmpeg_install_dir / OGG_INSTALL_DIR_NAME) / "pkgconfig"
    vorbis_pc_dir = (
        get_lib_dir(ffmpeg_install_dir / VORBIS_INSTALL_DIR_NAME) / "pkgconfig"
    )
    mp3lame_lib_dir = get_lib_dir(ffmpeg_install_dir / MP3LAME_INSTALL_DIR_NAME)
    mp3lame_include_dir = ffmpeg_install_dir / MP3LAME_INSTALL_DIR_NAME / "include"
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


def get_lib_search_paths(host: str) -> list[Path]:
    cc = f"{host}-gcc" if host else "gcc"
    try:
        res = run_command(
            [cc, "-print-search-dirs"],
            use_msys2=CURR_PLATFORM == "windows",
            text=True,
            capture_output=True,
            check=True,
        )
    except subprocess.CalledProcessError as e:
        raise ValueError("Failed to identify gcc search paths") from e

    out: str = res.stdout  # type: ignore
    search_paths: list[Path] = []

    for line in out.splitlines():
        if not line.startswith("libraries:"):
            continue

        search_paths += [
            Path(p)
            for p in line.strip()
            .removeprefix("libraries:")
            .strip()
            .removeprefix("=")
            .split(":")
        ]
    return search_paths


def find_file(name: str, search_paths: list[Path]) -> Path | None:
    for path in search_paths:
        if file := next(path.rglob(name), None):
            return file
        continue
    print(f'Couldn\'t find {name} in "{":".join(map(str, search_paths))}"')


def copy_lib_files_linux(arch: str):
    dest_dir = Path("..") / "bin" / f"linux_{arch}"
    host, sysroot = get_host_and_sysroot("linux", arch)

    # User defined environment variable takes priority if present
    search_paths = (
        ([Path(_GOZEN_CROSS_SYSROOT)] if _GOZEN_CROSS_SYSROOT else [])
        + get_lib_search_paths(host)
        + [sysroot]
    )

    dest_dir.mkdir(parents=True, exist_ok=True)

    print(f"Copying lib files to {dest_dir} ...")

    def find_deps(binary_path: Path) -> Generator[Path, None, None]:
        excluded_libs = [
            "libc.so.6",
            "libm.so.6",
            "libpthread.so.0",
            "libdl.so.2",
            "librt.so.1",
            "ld-linux-x86-64.so.2",
        ] + [p.name for p in ffmpeg_libs]

        output = run_command(
            ["objdump", "-p", str(binary_path)], capture_output=True, text=True
        )
        if output.returncode != 0:
            print(
                f"Objdump failed for {binary_path}: exit-code:{output.returncode} std-err:\n{output.stderr}"
            )
            return

        out: str = output.stdout # type: ignore
        for line in out.splitlines():
            if "NEEDED" not in line:
                continue

            lib_name = line.strip().removeprefix("NEEDED").strip()
            if lib_name in excluded_libs:
                continue

            lib_path = find_file(lib_name, search_paths)
            if not lib_path:
                continue

            yield lib_path

    copied_files: list[str] = []

    def copy_dependencies(binary_path: Path) -> None:
        for lib_path in find_deps(binary_path):
            if lib_path.name in copied_files:
                continue
            copied_files.append(lib_path.name)

            print(f"Copying {lib_path.name} from {lib_path.parent} to {dest_dir}")
            dest_path = dest_dir / lib_path.name

            if os.path.abspath(lib_path) == os.path.abspath(dest_path):
                print(
                    f'Couldn\'t copy. Source "{lib_path}" and destination "{dest_path}" point to the same file.'
                )
                continue  # Avoid SameFileError

            shutil.copy2(lib_path, dest_dir)

    ffmpeg_libs = [
        file for file in (get_ffmpeg_install_dir("linux") / "lib").glob("*.so.[0-9]*")
    ]
    for binary in ffmpeg_libs:
        shutil.copy2(binary, dest_dir)
        copy_dependencies(binary)

    print("Finished copying files!", flush=True)


def copy_lib_files_windows(arch: str):
    dest_dir = Path("..") / "bin" / f"windows_{arch}"
    host, sysroot = get_host_and_sysroot("windows", arch)

    # On msys2 the dlls are present in sysroot/bin, on Ubuntu in sysroot/lib
    # So we just use recursive search instad of specifying the full path
    search_paths = (
        ([Path(_GOZEN_CROSS_SYSROOT)] if _GOZEN_CROSS_SYSROOT else [])
        + get_lib_search_paths(host)
        + [sysroot]
    )

    extra_libs = [
        "libwinpthread-1.dll",
        "libgcc_s_seh-1.dll",
    ]

    print(f"Copying lib files to {dest_dir} ...")
    os.makedirs(dest_dir, exist_ok=True)

    for file in list((get_ffmpeg_install_dir("windows") / "bin").glob("*.dll")) + [
        find_file(dll, search_paths) for dll in extra_libs
    ]:
        if not file:
            continue

        print(f"Copying {file.name} from {file.parent} to {dest_dir}")
        shutil.copy2(file, dest_dir)

    print("Finished copying files!", flush=True)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", type=str, default="linux")
    parser.add_argument("--arch", type=str, default="x86_64")
    parser.add_argument("--threads", type=int, default=4)
    args = parser.parse_args()

    compile_ffmpeg(args.platform, args.arch, args.threads)
