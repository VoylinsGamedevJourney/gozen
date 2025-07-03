#!/usr/bin/env python3
"""
GDE GoZen Builder Script

This script handles the compilation of FFmpeg and the GDE GoZen plugin
for multiple platforms and architectures.

NOTE:
    Windows builds require MSYS2 and git to be installed.

usage: build.py [-h] [--default]

options:
  -h, --help     show this help message and exit
  --default      use default parameters

environment variables:
  GOZEN_MSYS2_DIR       path to the MSYS2 directory where MSYS2 is installed (default: C:\\msys64)
  GOZEN_GIT_PATH        path to the git executable (default: git)
  GOZEN_CROSS_SYSROOT   root of the cross-build tree, used when cross compiling (default: linux: auto-detect, windows: ${GOZEN_MSYS2_DIR}/ucrt64)

environment variable usage:
  windows       set GOZEN_MSYS2_DIR=C:\\msys64 && python3 build.py
  linux         export GOZEN_GIT_PATH=/usr/bin/git && python3 build.py
"""

import datetime
import os
import subprocess
import sys
from enum import IntEnum

from build_utils import build_ffmpeg, utils

DEFAULT_THREADS: int = os.cpu_count() or 4

TARGET_DEV: str = "debug"
TARGET_RELEASE: str = "release"


class ExitCode(IntEnum):
    SUCCESS = 0
    ERROR = 1
    UNSUPPORTED_PYTHON_VERSION = 2
    DEP_NOT_FOUND = 3
    UNSUPPORTED_PLATFORM = 4
    INVALID_OPTION = 5


def _print_options(title: str, options: list[str]) -> str:
    assert len(options) > 0
    print(f"{title}:")

    i = 1

    for option in options:
        if i == 1:
            print(f"{i}. {option}; (default)")
        else:
            print(f"{i}. {option};")
        i += 1

    for i in range(5):
        choice = input("> ").strip().lower()

        # Default
        if choice == "":
            return options[0]

        # Option
        option_map = {option.lower(): option for option in options}
        if choice in option_map:
            return option_map[choice]

        # Index
        if choice.isdecimal() and choice.isascii() and 1 <= int(choice) <= len(options):
            return options[int(choice) - 1]

        print(f"Invalid choice: {choice}." + (" Please try again." if i < 4 else ""))

    print("Aborting...")
    sys.exit(ExitCode.INVALID_OPTION)


def _print_nums(title: str, min: int, max: int | None, default: int) -> int:
    low = min or float("-inf")
    high = max or float("inf")
    print(f"{title} ({low} - {high}) (default: {default}):")
    for i in range(5):
        choice = input("> ").strip()

        # Default
        if choice == "":
            return default

        # Number
        if choice.isdecimal() and choice.isascii() and low <= int(choice) <= high:
            return int(choice)
        print(f"Invalid choice: {choice}." + (" Please try again." if i < 4 else ""))

    print("Aborting...")
    sys.exit(ExitCode.INVALID_OPTION)


def str_dt(dt: datetime.timedelta) -> str:
    mm, ss = divmod(dt.seconds, 60)
    hh, mm = divmod(mm, 60)
    return "%d hours %02d minutes %02d seconds" % (hh, mm, ss)


def main() -> ExitCode:
    print()
    print("v===================v")
    print("| GDE GoZen builder |")
    print("^===================^")
    print()

    if sys.version_info < (3, 10):
        print("Python 3.10+ is required to run this script!")
        return ExitCode.UNSUPPORTED_PYTHON_VERSION

    if utils.CURR_PLATFORM == "windows":
        # Oh no, Windows detected. ^^"
        if not utils.find_program(utils.GIT_PATH):
            print("Git is not installed in Windows!\nSteps to install Git:")
            print("\t1. Download Git installer from https://git-scm.com/")
            print("\t2. Run the installer to install Git")

            print(
                "If Git is installed at a non-standard path, please set the GOZEN_GIT_PATH environment variable."
            )
            print("Use --help for more information.")

            input("After installation, run this script again.\nPress Enter to exit...")
            return ExitCode.DEP_NOT_FOUND

        if utils.is_current_msys2_ucrt64():
            # UCRT64
            print("Running in UCRT64.")
        elif utils.is_current_msys2():
            # MSYS2
            print("Running in MSYS2. Restarting in UCRT64...")

            # Running the script from any MSYS2 environment others than UCRT64 is not tested
            # and may not work.
            # So, we restart the script in the UCRT64 environment.
            # Restarting in UCRT64 is a better option than restarting in a windows environment
            # because we will already know the install path of MSYS2="/".
            res = utils.run_command(
                ["python3", __file__],
                cwd="./",
                use_msys2=True,
                env={
                    "GOZEN_GIT_PATH": utils.GIT_PATH,
                },
            )
            return res.returncode  # type: ignore

            # For restarting in a windows environment:
            # explorer.exe resets the PATH environment variable then executes `python3 build.py`
            # utils.run_command(['explorer', sys.executable, __file__], cwd='./')
        else:
            # Cmd or Powershell
            # Try to check if MSYS2 is installed
            if not utils.is_msys2_installed():
                print("MSYS2 is not installed!\nSteps to install MSYS2:")
                print("\t1. Download MSYS2 installer from https://www.msys2.org/")
                print("\t2. Run the installer to install MSYS2")

                print(
                    "If MSYS2 is installed at a custom location, please set the GOZEN_MSYS2_DIR environment variable."
                )
                print("Use --help for more information.")

                input(
                    "After installation, run this script again.\nPress Enter to exit..."
                )
                return ExitCode.DEP_NOT_FOUND

    match _print_options("Init/Update submodules", ["no", "initialize", "update"]):
        case "initialize":
            subprocess.run(
                [utils.GIT_PATH, "submodule", "update", "--init", "--recursive"],
                cwd="./",
            )
        case "update":
            subprocess.run(
                [utils.GIT_PATH, "submodule", "update", "--recursive", "--remote"],
                cwd="./",
            )

    target_platform = (
        "windows"
        if utils.CURR_PLATFORM == "windows"
        else _print_options(
            "Choose target platform",
            ["linux", "windows"],
        )
    )
    if target_platform not in ["linux", "windows"]:
        print(f"Unsupported platform ({target_platform})")
        return ExitCode.UNSUPPORTED_PLATFORM

    # arm64 isn't supported yet by mingw for Windows, so x86_64 only.
    arch = "x86_64"
    if target_platform == "linux":
        arch = _print_options("Choose architecture", ["x86_64", "arm64"])

    target = _print_options("Select target", [TARGET_DEV, TARGET_RELEASE])
    threads = _print_nums(
        "Choose number of threads",
        1,
        os.cpu_count(),
        DEFAULT_THREADS,
    )

    should_compile_ffmpeg = (
        _print_options("Do you want to (re)compile ffmpeg?", ["yes", "no"]) == "yes"
    )

    # Install dependencies
    if utils.CURR_PLATFORM == "windows":
        print("Checking for missing MSYS2 dependencies ...")
        missing_packages = utils.check_required_programs_msys2()

        if missing_packages:
            print("Installing necessary MSYS2 dependencies ...")

            if utils.is_current_msys2():
                input(
                    "The terminal will automatically close after update.\nPress Enter to continue..."
                )

            install_success = utils.install_msys2_required_deps(missing_packages)

            if not install_success:
                print("Error installing dependencies!")
                print(
                    'Please run the following commands in the MSYS2\'s "ucrt64.exe" shell manually:'
                )
                print("\tpacman -Syu --noconfirm")
                print(
                    f"\tpacman -S {' '.join(utils.MSYS2_REQUIRED_PACKAGES)} --noconfirm"
                )

                input("Press Enter to exit...")
                return ExitCode.DEP_NOT_FOUND

            print("Successfully installed the required MSYS2 dependencies!")

    # Make sure that sysroot can be found
    try:
        utils.get_host_and_sysroot(target_platform, arch)
    except (FileNotFoundError, ValueError) as e:
        print(f"{type(e)}: {e}")

    start_time = datetime.datetime.now()

    # Compile ffmpeg
    if should_compile_ffmpeg:
        build_ffmpeg.compile_ffmpeg(target_platform, arch, int(threads))

    print(f"Built ffmpeg in {str_dt(datetime.datetime.now() - start_time)}\n")

    # Compile GDE GoZen
    command = [
        "scons",
        f"-j{threads}",
        f"target=template_{target}",
        f"platform={target_platform}",
        f"arch={arch}",
    ]
    if target_platform == "windows":
        command += ["use_static_cpp=yes", "use_mingw=yes"]

    res = utils.run_command(
        command,
        cwd="./",
        use_msys2=utils.CURR_PLATFORM == "windows",
    )

    if res.returncode != 0:
        print("Build failed.")
        return ExitCode.ERROR

    print(f"Built in {str_dt(datetime.datetime.now() - start_time)}")
    print()
    print("v=========================v")
    print("| Done building GDE GoZen |")
    print("^=========================^")
    print()
    return ExitCode.SUCCESS


if __name__ == "__main__":
    if "--help" in sys.argv or "-h" in sys.argv:
        print((__doc__ or "").strip())
        sys.exit(ExitCode.SUCCESS)

    if "--default" in sys.argv:
        # Override input to always return ""
        def input(prompt: object) -> str:
            print(prompt)
            return ""

    elif len(sys.argv) > 1:
        print("Unknown argument:", sys.argv[1])
        sys.exit(ExitCode.ERROR)

    sys.exit(main())
