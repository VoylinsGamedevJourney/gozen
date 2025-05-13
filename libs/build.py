#!/usr/bin/env python3
"""
GDE GoZen Builder Script

This script handles the compilation of FFmpeg and the GDE GoZen plugin
for multiple platforms and architectures.

NOTE:
    Windows and Linux can be build on Linux or Windows with WSL.
    For MacOS you need to use MacOS itself else building fails.
"""


import os
import sys
import platform as os_platform
import subprocess
import glob
import shutil


THREADS = os.cpu_count() or 4
PATH_BUILD_WINDOWS = 'build_on_windows.py'

TARGET_DEV: str = 'debug'
TARGET_RELEASE: str = 'release'

DISABLED_MODULES = [
    '--disable-avdevice',
    '--disable-postproc',
    '--disable-avfilter',
    '--disable-sndio',
    '--disable-doc',
    '--disable-programs',
    '--disable-ffprobe',
    '--disable-htmlpages',
    '--disable-manpages',
    '--disable-podpages',
    '--disable-txtpages',
    '--disable-ffplay',
    '--disable-ffmpeg'
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

    if os.path.exists('./ffmpeg/ffbuild/config.mak'):
        print('Cleaning FFmpeg...')

        subprocess.run(['make', 'distclean'], cwd='./ffmpeg/')
        subprocess.run(['rm', '-rf', 'bin_linux'], cwd='./ffmpeg/')
        subprocess.run(['rm', '-rf', 'bin_windows'], cwd='./ffmpeg/')
        subprocess.run(['rm', '-rf', 'bin_macos'], cwd='./ffmpeg/')

    if platform == 'linux':
        compile_ffmpeg_linux(arch)
        copy_lib_files_linux(arch)
    elif platform == 'windows':
        compile_ffmpeg_windows(arch)
        copy_lib_files_windows(arch)
    elif platform == 'macos':
        compile_ffmpeg_macos(arch)
        copy_lib_files_macos(arch)


def compile_ffmpeg_linux(arch):
    print('Configuring FFmpeg for Linux ...')
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
        '--enable-libx264',
        '--enable-libx265'
    ]
    cmd += DISABLED_MODULES

    subprocess.run(cmd, cwd='./ffmpeg/')

    print('Compiling FFmpeg for Linux ...')

    subprocess.run(['make', f'-j{THREADS}'], cwd='./ffmpeg/')
    subprocess.run(['make', 'install'], cwd='./ffmpeg/')

    print('Compiling FFmpeg for Linux finished!')


def copy_lib_files_linux(arch):
    path = f'bin/linux_{arch}'
    os.makedirs(path, exist_ok=True)

    print(f'Copying lib files to {path} ...')

    for file in glob.glob('ffmpeg/bin_linux/lib/*.so.*'):
        if file.count('.') == 2:
            shutil.copy2(file, path)

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
        '--quiet',
        '--extra-libs=-lpthread',
        '--extra-ldflags=-static -fpic',
        '--extra-cflags=-fPIC',
        # '--enable-libx264',
        # '--enable-libx265'
    ]
    cmd += DISABLED_MODULES

    subprocess.run(cmd, cwd='./ffmpeg/')

    print('Compiling FFmpeg for Windows ...')

    subprocess.run(['make', f'-j{THREADS}'], cwd='./ffmpeg/')
    subprocess.run(['make', 'install'], cwd='./ffmpeg/')

    print('Compiling FFmpeg for Windows finished!')


def copy_lib_files_windows(arch):
    path = f'bin/windows_{arch}'
    os.makedirs(path, exist_ok=True)

    print(f'Copying lib files to {path} ...')

    for file in glob.glob('ffmpeg/bin_windows/bin/*.dll'):
        shutil.copy2(file, path)

    os.system(f'cp /usr/x86_64-w64-mingw32/bin/libwinpthread-1.dll {path}')
    os.system(f'cp /usr/x86_64-w64-mingw32/bin/libstdc++-6.dll {path}')

    print('Copying files for Windows finished!')


def compile_ffmpeg_macos(arch):
    print('Configuring FFmpeg for MacOS ...')

    cmd = [
        './configure',
        '--prefix=./bin_macos',
        '--enable-shared',
        '--enable-gpl',
        '--enable-version3',
        '--enable-pthreads',
        f'--arch={arch}',
        '--extra-ldflags=-mmacosx-version-min=10.13',
        '--quiet',
        '--extra-cflags=-fPIC -mmacosx-version-min=10.13',
        '--enable-libx264',
        '--enable-libx265'
    ]
    cmd += DISABLED_MODULES

    subprocess.run(cmd, cwd='./ffmpeg/')

    print('Compiling FFmpeg for MacOS ...')

    subprocess.run(['make', f'-j{THREADS}'], cwd='./ffmpeg/')
    subprocess.run(['make', 'install'], cwd='./ffmpeg/')

    print('Compiling FFmpeg for MacOS finished!')


def copy_lib_files_macos(arch):
    path_debug = f'bin/macos_{arch}/debug/lib'
    path_release = f'bin/macos_{arch}/release/lib'

    os.makedirs(path_debug, exist_ok=True)
    os.makedirs(path_release, exist_ok=True)

    print(f'Copying lib files to {path_debug} & {path_release} ...')

    for file in glob.glob('./ffmpeg/bin_macos/lib/*.dylib'):
        shutil.copy2(file, path_debug)
        shutil.copy2(file, path_release)

    print('Copying files for MacOS finished!')


def macos_fix(arch):
    # This is a fix for the MacOS builds to get the libraries to properly connect to
    # the gdextension library. Without it, the FFmpeg libraries can't be found.
    print('Running fix for MacOS builds ...')

    debug_binary = f'./libs/bin/macos_{arch}/debug/libgozen.macos.template_debug.dev.{arch}.dylib'
    release_binary = f'./libs/bin/macos_{arch}/release/libgozen.macos.template_release.{arch}.dylib'
    debug_bin_folder = f'./libs/bin/macos_{arch}/debug/lib'
    release_bin_folder = f'./libs/bin/macos_{arch}/release/lib'

    print('Updating @loader_path for MacOS builds')

    if os.path.exists(debug_binary):
        for file in os.listdir(debug_bin_folder):
            os.system(f'install_name_tool -change ./bin/lib/{file} @loader_path/lib/{file} {debug_binary}')
        subprocess.run(['otool', '-L', debug_binary], cwd='./')

    if os.path.exists(release_binary):
        for file in os.listdir(release_bin_folder):
            os.system(f'install_name_tool -change ./bin/lib/{file} @loader_path/lib/{file} {release_binary}')
        subprocess.run(['otool', '-L', release_binary], cwd='./')


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
    match _print_options('Select platform', ['linux', 'linux_compatibility', 'windows', 'macos']):
        case '2':
            platform = 'linux_compatibility'
        case '3':
            platform = 'windows'
        case '4':
            platform = 'macos'

    # arm64 isn't supported yet by mingw for Windows, so x86_64 only.
    arch = 'x86_64' if platform != 'macos' else 'arm64'
    match platform:
        case 'linux':
            if _print_options('Choose architecture', ['x86_64', 'arm64']) == '2':
                arch = 'arm64'
        case 'macos':
            if _print_options('Select target', ['arm64', 'x86_64']) == '2':
                arch = 'x86_64'

    target = TARGET_DEV
    match _print_options('Select target', [TARGET_DEV, TARGET_RELEASE]):
        case '2':
            target = TARGET_RELEASE

    compile_ffmpeg(platform, arch)

    if platform == 'linux_compatibility':
        platform = 'linux'

    subprocess.run([
        'scons',
        f'-j{THREADS}',
        f'target=template_{target}',
        f'platform={platform}',
        f'arch={arch}'
    ], cwd='./')

    if platform == 'macos':
        macos_fix(arch)

    print()
    print('v=========================v')
    print('| Done building GDE GoZen |')
    print('^=========================^')
    print()


if __name__ == '__main__':
    main()
