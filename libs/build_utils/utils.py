#!/usr/bin/env python3

import os
import platform as os_platform
import shutil
import subprocess
import sysconfig
from pathlib import Path
from typing import Any, Literal

MSYS2_REQUIRED_PACKAGES = [
    "mingw-w64-ucrt-x86_64-binutils",
    "mingw-w64-ucrt-x86_64-crt-git",
    "mingw-w64-ucrt-x86_64-gcc",
    "mingw-w64-ucrt-x86_64-gdb",
    "mingw-w64-ucrt-x86_64-gdb-multiarch",
    "mingw-w64-ucrt-x86_64-headers-git",
    "mingw-w64-ucrt-x86_64-libmangle-git",
    "mingw-w64-ucrt-x86_64-libwinpthread",
    "mingw-w64-ucrt-x86_64-pkgconf",
    "mingw-w64-ucrt-x86_64-tools-git",
    "mingw-w64-ucrt-x86_64-winpthreads",
    "mingw-w64-ucrt-x86_64-winstorecompat-git",
    "mingw-w64-ucrt-x86_64-ninja",
    "mingw-w64-ucrt-x86_64-make",
    "mingw-w64-ucrt-x86_64-diffutils",
    "mingw-w64-ucrt-x86_64-yasm",
    "mingw-w64-ucrt-x86_64-nasm",
    "mingw-w64-ucrt-x86_64-python",
    "mingw-w64-ucrt-x86_64-scons",
    "mingw-w64-ucrt-x86_64-cmake",
    "mingw-w64-ucrt-x86_64-autotools",
]


_old_cwd: str = ""


def run_command(
    command: list[str],
    cwd: str | os.PathLike | None = None,
    env: dict[str, str] | None = None,
    check: bool = False,
    shell: bool = False,
    use_msys2: bool = False,
    **kwargs,
) -> subprocess.CompletedProcess[str | bytes | Any]:
    """
    Run command with arguments and return a CompletedProcess instance. Similar to `subprocess.run()`.

    If `use_msys2` is True, the command will be run in a MSYS2 shell defined by the `MSYS2_SHELL` global variable.
    Use of environment variables in the command is allowed in use_msys2 mode. Example:

        >>> run_command(["echo", "$MSYSTEM"], use_msys2=True)
        "UCRT64"

    Environment variables defined by the `env` parameter can also be used in the command. Example:

        >>> run_command(["echo", "$VAR], env={"VAR": "Hello World"}, use_msys2=True)
        "Hello World"

    Window style %environment_variables% are not expanded when use_msys2 is True. Example:

        >>> run_command(["echo", "\\%PATH\\%"], use_msys2=True)     # without \\
        "\\%PATH\\%"                                                # without \\

    By default, the current environment variables (os.environ) are inherited from the current process.
    This is NOT true when use_msys2 is True.
    DO NOT set `env=os.environ` when use_msys2 is True.

    In use_msys2 mode, all paths in the `command` and `env` must be MSYS2 style paths. See `convert_to_msys2_path()`.

    If `shell` is True, the command will be run in a shell (cmd.exe on Windows).
    Using both `shell` and `use_msys2` is not allowed.

    The rest of the parameters are the same as `subprocess.run()`.
    """
    global _old_cwd
    if _old_cwd != str(cwd or ""):
        print(f"$ cd {cwd}")
        _old_cwd = str(cwd or "")

    print(f"$ {' '.join(command)}", flush=True)

    if use_msys2:
        assert not shell, (
            "shell must be False when using msys2"
        )  # The command would likely work, but shell=True is not needed

        # Escape spaces and %
        # Escaping spaces will make sure that arguments with spaces are still treated as a single argument
        # Escaping % will make sure that windows style %environment_variables% are not expanded
        msys2_cmd = " ".join(
            [c.replace(" ", "\\ ").replace("%", "\\%") for c in command]
        )
        envs = (
            map(
                lambda item: (
                    item[0].replace(" ", "\\ ").replace("%", "\\%"),
                    item[1].replace(" ", "\\ ").replace("%", "\\%"),
                ),
                env.items(),
            )
            if env
            else []
        )
        exports = ";".join([f"export {k}={v}" for k, v in envs]) if envs else ""

        command = [
            *MSYS2_SHELL,
            ";".join((exports, msys2_cmd)) if exports else msys2_cmd,
        ]

        # print(f"$$ {' '.join(command)}", flush=True)
        return subprocess.run(command, cwd=cwd, check=check, shell=False, **kwargs)
    return subprocess.run(command, cwd=cwd, env=env, check=check, shell=shell, **kwargs)


def is_current_msys2_ucrt64() -> bool:
    """Returns True if running in a UCRT64 environment."""
    return sysconfig.get_platform() == "mingw_x86_64_ucrt_gnu"


def is_current_msys2() -> bool:
    """Returns True if running in any MSYS2 environment."""
    return sysconfig.get_platform().startswith("mingw")


def convert_to_msys2_path(path: str | Path) -> str:
    """
    Converts a path to a MSYS2 compatible path.
    This path can be used with the `run_command` function with `use_msys2=True`.
    Example:

        >>> convert_to_msys2_path('C:\\Users\\user\\Desktop\\file.txt')
        '/c/Users/user/Desktop/file.txt'
    """
    if CURR_PLATFORM != "windows":
        return str(Path(path).absolute().as_posix())

    cmd = ["cygpath", str(path)]
    if not is_current_msys2_ucrt64():
        _path = str(path).replace("\\", "/").replace(" ", "\\ ")
        cmd = [*MSYS2_SHELL, f"cygpath {_path}"]

    res = subprocess.run(cmd, cwd="./", capture_output=True, text=True, shell=False)
    if res.returncode != 0:
        raise ValueError(f"Failed to convert path {path} to MSYS2 path!")
    return res.stdout.strip().replace(" ", "\\ ")


def clear_dir(path: str | os.PathLike) -> None:
    """Clears an existing directory or creates a new one."""
    if os.path.exists(path):
        shutil.rmtree(path)
    os.makedirs(path, exist_ok=True)


def find_program(program: str) -> list[str]:
    """
    Returns a list of absolute paths to the given program.
    If the program is not found, returns an empty list.

    `program` should be the name of the program, or the full path to the program.
    """
    if os.path.exists(program):
        return [os.path.abspath(program)]

    command = (
        ["where", program] if os_platform.system() == "Windows" else ["which", program]
    )
    try:
        res = subprocess.run(command, capture_output=True, text=True, check=True)
        return [p.strip() for p in res.stdout.splitlines()]
    except subprocess.CalledProcessError:
        return []


def check_required_programs_msys2() -> list[str]:
    _installed = subprocess.run(
        [*MSYS2_SHELL, "pacman -Q"], capture_output=True, text=True, shell=False
    )
    if _installed.returncode != 0:
        print("Error checking for installed packages!")
        return MSYS2_REQUIRED_PACKAGES
    installed_packages = [p.split()[0] for p in _installed.stdout.strip().split("\n")]
    missing_programs = [
        p for p in MSYS2_REQUIRED_PACKAGES if p not in installed_packages
    ]

    return missing_programs


def is_msys2_installed() -> bool:
    try:
        return (
            subprocess.run(
                [str(MSYS2_DIR / "msys2_shell.cmd"), "--help"], capture_output=True
            ).returncode
            == 0
        )
    except FileNotFoundError:
        return False


def install_msys2_required_deps(missing_programs: list[str]) -> bool:
    if not missing_programs:
        return True

    try:
        run_command(["pacman", "-Syu", "--noconfirm"], check=True, use_msys2=True)
        run_command(
            [
                "pacman",
                "-S",
                *missing_programs,
                "--noconfirm",
            ],
            check=True,
            use_msys2=True,
        )
        return True
    except subprocess.CalledProcessError:
        return False


def find_msys2_win_dir() -> Path | None:
    """
    Returns the windows style MSYS2 directory if running in a MSYS2 environment.
    """
    if not is_current_msys2():
        return None

    try:
        return Path(
            subprocess.run(
                ["cygpath", "-w", "/"], capture_output=True, text=True, check=True
            ).stdout.strip()
        )
    except subprocess.CalledProcessError:
        return None


def get_host_and_sysroot(target_platform: str, arch: str) -> tuple[str, Path]:
    assert arch in ["x86_64", "arm64"]
    assert target_platform in ["windows", "linux"]
    if CURR_PLATFORM == "windows":
        assert target_platform == "windows", (
            "Cross compilation on windows not supported"
        )
        # Windows arm
        if arch == "arm64":
            raise ValueError("Compilation for windows arm64 not supported")
            return "", MSYS2_DIR / "clangarm64"

        # Windows x86_64
        return "", MSYS2_DIR / "ucrt64"

    assert CURR_PLATFORM == "linux", (
        f"Platform and arch combination ({target_platform}, {arch}) not supported on ({CURR_PLATFORM})"
    )

    # Cross compile for windows x86_64
    if target_platform == "windows":
        assert arch == "x86_64", "Cross compilation for windows_arm not supported"
        if _GOZEN_CROSS_SYSROOT:
            return "x86_64-w64-mingw32", Path(_GOZEN_CROSS_SYSROOT)

        mingw_path = Path("/") / "usr" / "x86_64-w64-mingw32"
        if not mingw_path.exists():
            mingw_path = Path("/") / "usr" / "x86_64-w64-mingw"

        if not mingw_path.exists():
            raise FileNotFoundError(
                "Mingw sysroot not found. Please specify the `GOZEN_CROSS_SYSROOT` environment variable."
            )

        sysroot = mingw_path / "sys-root" / "mingw"
        if not sysroot.exists():
            sysroot = mingw_path

        return "x86_64-w64-mingw32", sysroot

    # Cross compile for arm linux
    if arch == "arm64" and CURR_ARCH != "arm64":
        return "aarch64-linux-gnu", Path(
            _GOZEN_CROSS_SYSROOT
        ) if _GOZEN_CROSS_SYSROOT else Path("/") / "usr" / "aarch64-linux-gnu"

    # Compile for current platform and arch
    return "", Path("/")


# Basic Constants
CURR_PLATFORM = os_platform.system().lower()
CURR_ARCH: Literal["x86_64", "arm64"] = (
    "x86_64" if os_platform.machine() in ["x86_64", "ARM64", "i386"] else "arm64"
)
HOMEDRIVE: str = os.environ.get("HOMEDRIVE", "C:")

# GoZen Environment Variables
MSYS2_DIR: Path = Path(
    os.environ.get("GOZEN_MSYS2_DIR")
    or (find_msys2_win_dir() or f"{HOMEDRIVE}\\msys64")
)
GIT_PATH: str = os.environ.get("GOZEN_GIT_PATH") or (
    "git"
    if find_program("git") or CURR_PLATFORM != "windows"
    else f"{HOMEDRIVE}\\Program Files\\Git\\cmd\\git.exe"
)
_GOZEN_CROSS_SYSROOT = os.environ.get("GOZEN_CROSS_SYSROOT")

# Other Constants
MSYS2_SHELL: list[str] = [
    str(MSYS2_DIR / "msys2_shell.cmd"),
    "-ucrt64",
    "-no-start",
    "-defterm",
    "-here",
    "-c",
]
