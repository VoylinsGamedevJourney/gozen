import os
from typing import Optional, Sequence

from .paths import (
    AOM_BUILD_DIR,
    AOM_INSTALL_DIR_NAME,
    AOM_SOURCE_DIR,
    MP3LAME_INSTALL_DIR_NAME,
    MP3LAME_SOURCE_DIR,
    OGG_INSTALL_DIR_NAME,
    OGG_SOURCE_DIR,
    OPUS_INSTALL_DIR_NAME,
    OPUS_SOURCE_DIR,
    SVT_AV1_BUILD_DIR,
    SVT_AV1_INSTALL_DIR_NAME,
    SVT_AV1_SOURCE_DIR,
    VORBIS_INSTALL_DIR_NAME,
    VORBIS_SOURCE_DIR,
    VPX_INSTALL_DIR_NAME,
    VPX_SOURCE_DIR,
    X264_INSTALL_DIR_NAME,
    X264_SOURCE_DIR,
    X265_BUILD_DIR,
    X265_INSTALL_DIR_NAME,
    X265_SOURCE_DIR,
    get_ffmpeg_install_dir,
)
from .utils import (
    get_host_and_sysroot,
    CURR_PLATFORM,
    clear_dir,
    convert_to_msys2_path,
    run_command,
)


def build_lib(
    lib_name: str,
    build_dir: str | os.PathLike,
    configure_cmd: list[str] | Sequence[list[str]],
    compile_cmd: Optional[list[str] | Sequence[list[str]]] = None,
    threads: int = 4,
    env: Optional[dict[str, str]] = None,
    use_msys2: bool = False,
) -> None:
    """Builds a library.

    Parameters
    ----------
    lib_name : str
        Name of the library.
    build_dir : str
        Directory where the build commands are to be executed.
    configure_cmd : list[str] | Sequence[list[str]]
        Command(s) to configure the library.
    compile_cmd : Optional[list[str] | Sequence[list[str]]], optional
        Command(s) to compile the library. Defaults to [["make", f"-j{threads}"], ["make", "install"]].
    threads : int, optional
        Number of threads to use.
    env : Optional[dict], optional
        Environment variables to use.
    use_msys2 : bool, optional
        Whether to use msys2.
    """
    assert all(isinstance(cmd, str) for cmd in configure_cmd) or all(
        isinstance(cmd, list) for cmd in configure_cmd
    ), "configure_cmd must be a list of strings or a list of lists of strings."

    assert (
        compile_cmd is None
        or all(isinstance(cmd, str) for cmd in compile_cmd)
        or all(isinstance(cmd, list) for cmd in compile_cmd)
    ), "configure_cmd must be a list of strings or a list of lists of strings."

    print(f"Configuring {lib_name} ...", flush=True)

    build_env = env or {}
    compile_cmd = compile_cmd or [["make", f"-j{threads}"], ["make", "install"]]

    configure_cmds: list[list[str]] = (
        configure_cmd if isinstance(configure_cmd[0], list) else [configure_cmd]  # type: ignore
    )
    compile_cmds: list[list[str]] = (
        compile_cmd if isinstance(compile_cmd[0], list) else [compile_cmd]  # type: ignore
    )

    for cmd in configure_cmds:
        run_command(
            cmd,
            cwd=build_dir,
            env=build_env,
            check=True,
            shell=False,
            use_msys2=use_msys2,
        )

    print(f"Compiling {lib_name}...", flush=True)

    for cmd in compile_cmds:
        run_command(
            cmd,
            cwd=build_dir,
            env=build_env,
            check=True,
            use_msys2=use_msys2,
        )

    print(f"Compiling {lib_name} finished!", flush=True)


def build_x264(
    platform: str, arch: str, threads: int, env: dict[str, str] | None = None
):
    if X264_SOURCE_DIR.exists():
        run_command(
            ["make", "distclean"],
            cwd=X264_SOURCE_DIR,
            use_msys2=CURR_PLATFORM == "windows",
        )
    install_dir = get_ffmpeg_install_dir(platform) / X264_INSTALL_DIR_NAME
    clear_dir(install_dir)

    host, _ = get_host_and_sysroot(platform, arch)

    build_lib(
        "x264",
        os.path.abspath(X264_SOURCE_DIR),
        configure_cmd=[
            "./configure",
            f"--prefix={convert_to_msys2_path(install_dir)}",
            "--enable-static",
            "--disable-cli",
            "--enable-pic",
            "--disable-avs",
            "--extra-ldflags=-lpthread",
        ]
        + ([f"--host={host}", f"--cross-prefix={host}-"] if host else []),
        threads=threads,
        env=env,
        use_msys2=CURR_PLATFORM == "windows",
    )


def build_x265(
    platform: str, arch: str, threads: int, env: dict[str, str] | None = None
):
    install_dir = get_ffmpeg_install_dir(platform) / X265_INSTALL_DIR_NAME
    source_dir = X265_SOURCE_DIR / "source"

    if X265_BUILD_DIR.exists():
        run_command(
            ["ninja", "-t", "clean", "-g"],
            cwd=X265_BUILD_DIR,
            use_msys2=CURR_PLATFORM == "windows",
        )
    clear_dir(install_dir)

    host, _ = get_host_and_sysroot(platform, arch)

    build_lib(
        "x265",
        X265_BUILD_DIR,
        configure_cmd=[
            "cmake",
            "-G=Ninja",
            "--fresh",
            f"-DCMAKE_INSTALL_PREFIX={convert_to_msys2_path(install_dir)}",
            "-DENABLE_SHARED=OFF",
            "-DENABLE_PIC=ON",
            f"{convert_to_msys2_path(source_dir)}",
        ]
        + (
            [
                f"-DCMAKE_SYSTEM_NAME={'Windows' if platform == 'windows' else 'Linux'}",
                f"-DCMAKE_SYSTEM_PROCESSOR={arch if arch == 'x86_64' else 'aarch64'}",
                f"-DCMAKE_C_COMPILER={host}-gcc",
                f"-DCMAKE_CXX_COMPILER={host}-g++",
                f"-DCMAKE_C_COMPILER_AR={host}-gcc-ar",
                f"-DCMAKE_CXX_COMPILER_AR={host}-gcc-ar",
                f"-DCMAKE_RC_COMPILER={host}-windres",
            ]
            if host
            else []
        ),
        compile_cmd=[["ninja", f"-j{threads}"], ["ninja", "install"]],
        threads=threads,
        env=env,
        use_msys2=CURR_PLATFORM == "windows",
    )


def build_aom(
    platform: str, arch: str, threads: int, env: dict[str, str] | None = None
):
    install_dir = get_ffmpeg_install_dir(platform) / AOM_INSTALL_DIR_NAME

    if AOM_BUILD_DIR.exists():
        run_command(
            ["ninja", "-t", "clean", "-g"],
            cwd=AOM_BUILD_DIR,
            use_msys2=CURR_PLATFORM == "windows",
        )
    clear_dir(install_dir)
    clear_dir(AOM_BUILD_DIR)

    host, _ = get_host_and_sysroot(platform, arch)
    if not host:
        toolchain_file = ""
    elif host == "x86_64-w64-mingw32":
        toolchain_file = "x86_64-mingw-gcc.cmake"
    elif host == "aarch64-linux-gnu":
        toolchain_file = "arm64-linux-gcc.cmake"
    else:
        raise ValueError(f"Toolchain file for host {host} unknown.")

    build_lib(
        "AOM",
        AOM_BUILD_DIR,
        configure_cmd=[
            "cmake",
            "-G=Ninja",
            "--fresh",
            f"-DCMAKE_INSTALL_PREFIX={convert_to_msys2_path(install_dir)}",
            "-DENABLE_TESTS=OFF",
            "-DCONFIG_PIC=1",
            f"{convert_to_msys2_path(AOM_SOURCE_DIR)}",
        ]
        + (
            [
                "-DCMAKE_TOOLCHAIN_FILE="
                + convert_to_msys2_path(
                    AOM_SOURCE_DIR / "build" / "cmake" / "toolchains" / toolchain_file
                )
            ]
            if toolchain_file
            else []
        ),
        compile_cmd=[["ninja", f"-j{threads}"], ["ninja", "install"]],
        threads=threads,
        env=env,
        use_msys2=CURR_PLATFORM == "windows",
    )


def build_svt_av1(
    platform: str, arch: str, threads: int, env: dict[str, str] | None = None
):
    install_dir = get_ffmpeg_install_dir(platform) / SVT_AV1_INSTALL_DIR_NAME

    if SVT_AV1_BUILD_DIR.exists():
        run_command(
            ["ninja", "-t", "clean", "-g"],
            cwd=SVT_AV1_BUILD_DIR,
            use_msys2=CURR_PLATFORM == "windows",
        )
    clear_dir(install_dir)

    host, _ = get_host_and_sysroot(platform, arch)

    build_lib(
        "SVT-AV1",
        SVT_AV1_BUILD_DIR,
        configure_cmd=[
            "cmake",
            "-G=Ninja",
            "--fresh",
            f"-DCMAKE_INSTALL_PREFIX={convert_to_msys2_path(install_dir)}",
            "-DCMAKE_BUILD_TYPE=Release",
            "-DBUILD_SHARED_LIBS=OFF",
            "-DBUILD_APPS=OFF",
            "-DCMAKE_POLICY_VERSION_MINIMUM=3.5",
            f"{convert_to_msys2_path(SVT_AV1_SOURCE_DIR)}",
        ]
        + (
            [
                f"-DCMAKE_SYSTEM_NAME={'Windows' if platform == 'windows' else 'Linux'}",
                f"-DCMAKE_SYSTEM_PROCESSOR={arch if arch == 'x86_64' else 'aarch64'}",
                f"-DCMAKE_C_COMPILER={host}-gcc",
                f"-DCMAKE_CXX_COMPILER={host}-g++",
                f"-DCMAKE_C_COMPILER_AR={host}-gcc-ar",
                f"-DCMAKE_CXX_COMPILER_AR={host}-gcc-ar",
                f"-DCMAKE_RC_COMPILER={host}-windres",
            ]
            if host
            else []
        ),
        compile_cmd=[["ninja", f"-j{threads}"], ["ninja", "install"]],
        threads=threads,
        env=env,
        use_msys2=CURR_PLATFORM == "windows",
    )


def build_vpx(
    platform: str, arch: str, threads: int, env: dict[str, str] | None = None
):
    install_dir = get_ffmpeg_install_dir(platform) / VPX_INSTALL_DIR_NAME

    if VPX_SOURCE_DIR.exists():
        run_command(
            ["make", "distclean"],
            cwd=VPX_SOURCE_DIR,
            use_msys2=CURR_PLATFORM == "windows",
        )
    clear_dir(install_dir)

    env = env or {}

    host, _ = get_host_and_sysroot(platform, arch)
    target = ""
    if host:
        triplet_plt = "win64" if platform == "windows" else platform
        triplet_arch = arch
        target = f"{triplet_arch}-{triplet_plt}-gcc"

    if host:
        env["CROSS"] = f"{host}-"

    build_lib(
        "VPX",
        VPX_SOURCE_DIR,
        configure_cmd=[
            "./configure",
            f"--prefix={convert_to_msys2_path(install_dir)}",
            "--disable-examples",
            "--disable-unit-tests",
            "--enable-vp9-highbitdepth",
            "--disable-docs",
            "--enable-pic",
        ]
        + ([f"--target={target}"] if target else []),
        threads=threads,
        env=env,
        use_msys2=CURR_PLATFORM == "windows",
    )


def build_opus(
    platform: str, arch: str, threads: int, env: dict[str, str] | None = None
):
    install_dir = get_ffmpeg_install_dir(platform) / OPUS_INSTALL_DIR_NAME

    if OPUS_SOURCE_DIR.exists():
        run_command(
            ["make", "distclean"],
            cwd=OPUS_SOURCE_DIR,
            use_msys2=CURR_PLATFORM == "windows",
        )
    clear_dir(install_dir)

    host, _ = get_host_and_sysroot(platform, arch)

    build_lib(
        "Opus",
        OPUS_SOURCE_DIR,
        configure_cmd=(
            ["./autogen.sh"],
            [
                "./configure",
                f"--prefix={convert_to_msys2_path(install_dir)}",
                "--disable-shared",
                "--with-pic",
                "--disable-doc",
            ]
            + ([f"--host={host}"] if host else []),
        ),
        threads=threads,
        env=env,
        use_msys2=CURR_PLATFORM == "windows",
    )


def build_ogg(
    platform: str, arch: str, threads: int, env: dict[str, str] | None = None
):
    install_dir = get_ffmpeg_install_dir(platform) / OGG_INSTALL_DIR_NAME

    if OGG_SOURCE_DIR.exists():
        run_command(
            ["make", "distclean"],
            cwd=OGG_SOURCE_DIR,
            use_msys2=CURR_PLATFORM == "windows",
        )
    clear_dir(install_dir)

    host, _ = get_host_and_sysroot(platform, arch)

    build_lib(
        "ogg",
        OGG_SOURCE_DIR,
        configure_cmd=(
            ["./autogen.sh"],
            [
                "./configure",
                f"--prefix={convert_to_msys2_path(install_dir)}",
                "--disable-shared",
                "--enable-pic",
            ]
            + ([f"--host={host}"] if host else []),
        ),
        threads=threads,
        env=env,
        use_msys2=CURR_PLATFORM == "windows",
    )


def build_vorbis(platform: str, arch: str, threads: int, env: dict[str, str]):
    install_dir = get_ffmpeg_install_dir(platform) / VORBIS_INSTALL_DIR_NAME

    if VORBIS_SOURCE_DIR.exists():
        run_command(
            ["make", "distclean"],
            cwd=VORBIS_SOURCE_DIR,
            use_msys2=CURR_PLATFORM == "windows",
        )
    clear_dir(install_dir)

    pc_path = (
        os.environ.get("PKG_CONFIG_PATH", "")
        if CURR_PLATFORM != "windows"
        else "$PKG_CONFIG_PATH"  # will expand automatically in use_msys2=True mode
    )

    ogg_pkgconfig_dir = (
        get_ffmpeg_install_dir(platform) / OGG_INSTALL_DIR_NAME / "lib" / "pkgconfig"
    )
    env["PKG_CONFIG_PATH"] = convert_to_msys2_path(ogg_pkgconfig_dir) + (
        (":" + pc_path) if pc_path else ""
    )
    if platform == "windows" and CURR_PLATFORM != platform:
        env["PKG_CONFIG"] = (
            "pkg-config"  # `x86_64-w64-mingw32-pkg-config` prepends `/usr/x86_64-w64-mingw32/sys-root/mingw/` to all paths
        )

    host, _ = get_host_and_sysroot(platform, arch)

    build_lib(
        "vorbis",
        os.path.abspath(VORBIS_SOURCE_DIR),
        configure_cmd=(
            ["./autogen.sh"],
            [
                "./configure",
                f"--prefix={convert_to_msys2_path(install_dir)}",
                "--disable-shared",
                "--enable-pic",
            ]
            + ([f"--host={host}"] if host else []),
        ),
        threads=threads,
        env=env,
        use_msys2=CURR_PLATFORM == "windows",
    )


def build_mp3lame(
    platform: str, arch: str, threads: int, env: dict[str, str] | None = None
):
    install_dir = get_ffmpeg_install_dir(platform) / MP3LAME_INSTALL_DIR_NAME

    if MP3LAME_SOURCE_DIR.exists():
        run_command(
            ["make", "distclean"],
            cwd=MP3LAME_SOURCE_DIR,
            use_msys2=CURR_PLATFORM == "windows",
        )
    clear_dir(install_dir)

    host, _ = get_host_and_sysroot(platform, arch)

    build_lib(
        "mp3lame",
        MP3LAME_SOURCE_DIR,
        configure_cmd=[
            "./configure",
            f"--prefix={convert_to_msys2_path(install_dir)}",
            "--disable-shared",
            "--enable-nasm",
            "--disable-decoder",
            "--disable-frontend",
            "--with-pic=yes",
        ]
        + ([f"--host={host}"] if host else []),
        threads=threads,
        env=env,
        use_msys2=CURR_PLATFORM == "windows",
    )
