#!/usr/bin/env python3
"""
GDE GoZen Builder Script

This script handles the compilation of FFmpeg and the GDE GoZen plugin
for multiple platforms and architectures.

NOTE:
    Windows and Linux can be build on Linux or Windows with WSL.
"""


import os
import sys
import platform as os_platform
import subprocess
import glob
import shutil


THREADS = os.cpu_count() or 4
PATH_BUILD_WINDOWS = 'build_on_windows.py'

FFMPEG_SOURCE_DIR: str = './ffmpeg'

TARGET_DEV: str = 'debug'
TARGET_RELEASE: str = 'release'

DISABLED_MODULES = [
    '--disable-avdevice',
    '--disable-postproc',
    '--disable-avfilter',
    '--disable-sndio',
    '--disable-doc',
    '--disable-programs',
    '--disable-htmlpages',
    '--disable-manpages',
    '--disable-podpages',
    '--disable-txtpages',
]


def _print_options(title, options):
    print(f'{title}:')

    i = 1

    for option in options:
        if i == 1:
            print(f'{i}. {option}; (default)')
        else:
            print(f'{i}. {option};')
        i += 1

    return input('> ')


def compile_ffmpeg(platform, arch):
    match _print_options('Do you want to (re)compile ffmpeg?', ['yes', 'no']):
        case '2':
            return

    if os.path.exists(f'{FFMPEG_SOURCE_DIR}/ffbuild/config.mak'):
        print('Cleaning FFmpeg...')

        subprocess.run(['make', 'distclean'], cwd=FFMPEG_SOURCE_DIR)
        subprocess.run(['rm', '-rf', 'bin_linux'], cwd=FFMPEG_SOURCE_DIR)
        subprocess.run(['rm', '-rf', 'bin_windows'], cwd=FFMPEG_SOURCE_DIR)

    if platform == 'linux':
        compile_ffmpeg_linux(arch)
        copy_lib_files_linux(arch)
    elif platform == 'windows':
        compile_ffmpeg_windows(arch)
        copy_lib_files_windows(arch)


def compile_ffmpeg_linux(arch):
    print('Configuring FFmpeg for Linux ...')

    try:
        # Get all default pkg-config paths from the system
        pc_paths = subprocess.check_output(
            ['pkg-config', '--variable', 'pc_path', 'pkg-config']
        ).decode().strip().split(':')

        # Also include ffmpeg's local install path if you're installing into ./bin_linux
        pc_paths.insert(0, os.path.abspath('ffmpeg/bin_linux/lib/pkgconfig'))

        # Export all paths to the environment
        os.environ['PKG_CONFIG_PATH'] = ':'.join(pc_paths)

        print('PKG_CONFIG_PATH set to:', os.environ['PKG_CONFIG_PATH'])

    except subprocess.CalledProcessError:
        print('Warning: pkg-config not found or failed. Using default path.')
        os.environ['PKG_CONFIG_PATH'] = '/usr/lib/pkgconfig'

    cmd = [
        './configure',
        '--prefix=./bin_linux',
        '--enable-shared',
        '--enable-gpl',
        '--enable-version3',
        '--enable-pthreads',
        f'--arch={arch}',
        '--target-os=linux',
        '--enable-pic',
        '--extra-cflags=-fPIC',
        '--extra-ldflags=-fPIC',
        '--pkg-config-flags=--static',
        '--enable-libx264',
        '--enable-libx265'
    ]
    cmd += DISABLED_MODULES

    subprocess.run(cmd, cwd=FFMPEG_SOURCE_DIR)

    print('Compiling FFmpeg for Linux ...')

    subprocess.run(['make', f'-j{THREADS}'], cwd=FFMPEG_SOURCE_DIR)
    subprocess.run(['make', 'install'], cwd=FFMPEG_SOURCE_DIR)

    print('Compiling FFmpeg for Linux finished!')


def copy_lib_files_linux(arch):
    path = f'bin/linux_{arch}'
    os.makedirs(path, exist_ok=True)

    print(f'Copying lib files to {path} ...')

    for file in glob.glob('ffmpeg/bin_linux/lib/*.so.*'):
        if file.count('.') == 2:
            shutil.copy2(file, path)

    print('Finding and copying required system .so dependencies ...')

    def copy_dependencies(binary_path):
        try:
            output = subprocess.check_output(['ldd', binary_path], text=True)
            for line in output.splitlines():
                if '=>' not in line:
                    continue
                parts = line.strip().split('=>')
                if len(parts) < 2:
                    continue
                lib_path = parts[1].split('(')[0].strip()
                if os.path.isfile(lib_path):
                    shutil.copy2(lib_path, path)
        except subprocess.CalledProcessError as e:
            print(f"Failed to run ldd on {binary_path}: {e}")

    # TODO: Make this work without manually adding version number
    binaries = [
        f'{path}/libavcodec.so.60',
        f'{path}/libavformat.so.60',
        f'{path}/libavutil.so.58',
        f'{path}/libswscale.so.7',
        f'{path}/libswresample.so.4',
        # f'bin/linux_{arch}/libgozen.linux.template_debug.{arch}.so'
    ]

    # TODO: Make this not copy all libraries, only needed ones (x264, x265)
    for binary in binaries:
        if os.path.exists(binary):
            copy_dependencies(binary)
        else:
            print(f"Warning: {binary} not found, skipping...")

    print('Copying files for Linux finished!')


def compile_ffmpeg_windows(arch):
    print('Configuring FFmpeg for Windows ...')

    os.environ['PKG_CONFIG_LIBDIR'] = f'/usr/{arch}-w64-mingw32/lib/pkgconfig'
    os.environ['PKG_CONFIG_PATH'] = f'/usr/{arch}-w64-mingw32/lib/pkgconfig'

    cmd = [
        './configure',
        '--prefix=./bin_windows',
        '--enable-shared',
        '--enable-gpl',
        '--enable-version3',
        f'--arch={arch}',
        '--target-os=mingw32',
        '--enable-cross-compile',
        f'--cross-prefix={arch}-w64-mingw32-',
        f'--pkg-config={arch}-w64-mingw32-pkg-config',
        '--quiet',
        '--extra-libs=-lpthread',
        '--extra-ldflags=-fPIC  -static-libgcc -static-libstdc++',
        '--extra-cflags=-fPIC -O2',
        '--enable-libx264',
        '--enable-libx265'
    ]
    cmd += DISABLED_MODULES

    subprocess.run(cmd, cwd=FFMPEG_SOURCE_DIR)

    print('Compiling FFmpeg for Windows ...')

    subprocess.run(['make', f'-j{THREADS}'], cwd=FFMPEG_SOURCE_DIR)
    subprocess.run(['make', 'install'], cwd=FFMPEG_SOURCE_DIR)

    print('Compiling FFmpeg for Windows finished!')


def copy_lib_files_windows(arch):
    path = f'bin/windows_{arch}'
    os.makedirs(path, exist_ok=True)

    print(f'Copying lib files to {path} ...')

    for file in glob.glob('ffmpeg/bin_windows/bin/*.dll'):
        shutil.copy2(file, path)

    os.system(f'cp /usr/x86_64-w64-mingw32/bin/libwinpthread-1.dll {path}')
    os.system(f'cp /usr/x86_64-w64-mingw32/bin/libstdc++-6.dll {path}')
    os.system(f'cp /usr/x86_64-w64-mingw32/bin/libx264.dll {path}')
    os.system(f'cp /usr/x86_64-w64-mingw32/bin/libx265.dll {path}')

    print('Copying files for Windows finished!')


def main():
    print()
    print('v===================v')
    print('| GDE GoZen builder |')
    print('^===================^')
    print()

    if sys.version_info < (3, 10):
        print('Python 3.10+ is required to run this script!')
        sys.exit(2)

    if os_platform.system() == 'Windows':
        # Oh no, Windows detected. ^^"
        subprocess.run([sys.executable, PATH_BUILD_WINDOWS], cwd='./', check=True)
        sys.exit(3)

    match _print_options('Init/Update submodules', ['no', 'initialize', 'update']):
        case 2:
            subprocess.run(['git', 'submodule', 'update',
                            '--init', '--recursive'], cwd='./')
        case 3:
            subprocess.run(['git', 'submodule', 'update',
                            '--recursive', '--remote'], cwd='./')

    platform = 'linux'
    match _print_options('Select platform', ['linux', 'windows']):
        case '2':
            platform = 'windows'

    # arm64 isn't supported yet by mingw for Windows, so x86_64 only.
    arch = 'x86_64'
    match platform:
        case 'linux':
            if _print_options('Choose architecture', ['x86_64', 'arm64']) == '2':
                arch = 'arm64'

    target = TARGET_DEV
    match _print_options('Select target', [TARGET_DEV, TARGET_RELEASE]):
        case '2':
            target = TARGET_RELEASE

    compile_ffmpeg(platform, arch)

    subprocess.run([
        'scons',
        f'-j{THREADS}',
        f'target=template_{target}',
        f'platform={platform}',
        f'arch={arch}'
    ], cwd='./')

    print()
    print('v=========================v')
    print('| Done building GDE GoZen |')
    print('^=========================^')
    print()


if __name__ == '__main__':
    main()
