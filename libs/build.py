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


THREADS: int = os.cpu_count() or 4
PATH_BUILD_WINDOWS: str = 'build_on_windows.py'

FFMPEG_SOURCE_DIR: str = './ffmpeg'

X264_REPO: str = 'https://code.videolan.org/videolan/x264.git'
X264_DIR: str = 'x264_src'
X264_WINDOWS_DIR: str = 'bin_windows/x264'

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
        print('Cleaning FFmpeg...', flush=True)

        subprocess.run(['make', 'distclean'], cwd=FFMPEG_SOURCE_DIR)
        subprocess.run(['rm', '-rf', 'bin_linux'], cwd=FFMPEG_SOURCE_DIR)
        subprocess.run(['rm', '-rf', 'bin_windows'], cwd=FFMPEG_SOURCE_DIR)

    if platform == 'linux':
        compile_ffmpeg_linux(arch)
        copy_lib_files_linux(arch)
    elif platform == 'windows':
        build_windows_x264()
        compile_ffmpeg_windows(arch)
        copy_lib_files_windows(arch)


def compile_ffmpeg_linux(arch):
    print('Configuring FFmpeg for Linux ...', flush=True)

    try:
        pc_paths = subprocess.check_output(
            ['pkg-config', '--variable', 'pc_path', 'pkg-config']
        ).decode().strip().split(':')
        pc_paths.insert(0, os.path.abspath('ffmpeg/bin_linux/lib/pkgconfig'))
        os.environ['PKG_CONFIG_PATH'] = ':'.join(pc_paths)

        print('PKG_CONFIG_PATH set to:', os.environ['PKG_CONFIG_PATH'], flush=True)

    except subprocess.CalledProcessError:
        print('Warning: pkg-config not found or failed. Using default path.', flush=True)
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
        '--enable-libx265',
        '--enable-libmp3lame',
        '--enable-libopus',
        '--enable-libvorbis',
    ]
    cmd += DISABLED_MODULES

    subprocess.run(cmd, cwd=FFMPEG_SOURCE_DIR, env=os.environ, check=True)

    print('Compiling FFmpeg for Linux ...', flush=True)

    subprocess.run(['make', f'-j{THREADS}'], cwd=FFMPEG_SOURCE_DIR, env=os.environ, check=True)
    subprocess.run(['make', 'install'], cwd=FFMPEG_SOURCE_DIR, env=os.environ, check=True)

    print('Compiling FFmpeg for Linux finished!', flush=True)


def copy_lib_files_linux(arch):
    path = f'bin/linux_{arch}'
    os.makedirs(path, exist_ok=True)

    print(f'Copying lib files to {path} ...')

    for file in glob.glob('ffmpeg/bin_linux/lib/*.so.*'):
        if file.count('.') == 2:
            shutil.copy2(file, path)

    print('Finding and copying required system .so dependencies ...', flush=True)

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
                if not os.path.isfile(lib_path):
                    continue

                print(lib_path)

                if any(lib_path.endswith(name) for name in (
                    'libc.so.6',
                    'libm.so.6',
                    'libpthread.so.0',
                    'libdl.so.2',
                    'librt.so.1',
                    'ld-linux-x86-64.so.2',
                )):
                    continue

                shutil.copy2(lib_path, path)
        except subprocess.CalledProcessError as e:
            print(f'Failed to run ldd on {binary_path}: {e}')

    # TODO: Make this work without manually adding version number
    binaries = [
        f'{path}/libavcodec.so.60',
        f'{path}/libavformat.so.60',
        f'{path}/libavutil.so.58',
        f'{path}/libswscale.so.7',
        f'{path}/libswresample.so.4',
        f'bin/linux_{arch}/libgozen.linux.template_debug.{arch}.so'
    ]

    # TODO: Make this not copy all libraries, only needed ones (x264, x265)
    for binary in binaries:
        if os.path.exists(binary):
            copy_dependencies(binary)
        else:
            print(f'Warning: {binary} not found, skipping...')

    print('Copying files for Linux finished!', flush=True)


def compile_ffmpeg_windows(arch):
    print('Configuring FFmpeg for Windows ...', flush=True)

    x264_install_base_dir: str = os.path.abspath(f'ffmpeg/{X264_WINDOWS_DIR}')
    x264_include_dir: str = f'{x264_install_base_dir}/include'
    x264_lib_dir: str = f'{x264_install_base_dir}/lib'
    x264_pkgconfig_dir: str = f'{x264_lib_dir}/pkgconfig'

    x265_install_base_dir: str = os.path.abspath(f'ffmpeg/{X265_WINDOWS_DIR}')
    x265_include_dir: str = f'{x265_install_base_dir}/include'
    x265_lib_dir: str = f'{x265_install_base_dir}/lib'
    x265_pkgconfig_dir: str = f'{x265_lib_dir}/pkgconfig'
    ffmpeg_env = os.environ.copy()

    ffmpeg_env['PKG_CONFIG_PATH'] = os.pathsep.join([
        x264_pkgconfig_dir,
        x265_pkgconfig_dir,
        '/usr/x86_64-w64-mingw32/lib/pkgconfig',
    ])

    cmd = [
        './configure',
        '--prefix=./bin_windows',
        '--enable-shared',
        '--enable-gpl',
        '--enable-version3',
        f'--arch={arch}',
        '--target-os=mingw32',
        '--enable-cross-compile',
        '--cross-prefix=x86_64-w64-mingw32-',
        '--pkg-config=pkg-config',
        '--extra-libs=-lpthread',
        f'--extra-cflags=-I{x264_include_dir} -I{x265_include_dir}',
        f'--extra-ldflags=-L{x264_lib_dir} -L{x265_lib_dir}',
        '--enable-libx264',
        '--enable-libx265',
    ]
    cmd += DISABLED_MODULES

    subprocess.run(cmd, cwd=FFMPEG_SOURCE_DIR, env=ffmpeg_env, check=True)

    print('Compiling FFmpeg for Windows ...', flush=True)

    subprocess.run(['make', f'-j{THREADS}'], cwd=FFMPEG_SOURCE_DIR, env=ffmpeg_env, check=True)
    subprocess.run(['make', 'install'], cwd=FFMPEG_SOURCE_DIR, env=ffmpeg_env, check=True)

    print('Compiling FFmpeg for Windows finished!', flush=True)


def copy_lib_files_windows(arch):
    path = f'bin/windows_{arch}'
    os.makedirs(path, exist_ok=True)

    print(f'Copying lib files to {path} ...')

    for file in glob.glob('ffmpeg/bin_windows/bin/*.dll'):
        shutil.copy2(file, path)

    os.system(f'cp ffmpeg/bin_windows/x264/bin/* {path}')
    os.system(f'cp ffmpeg/bin_windows/x265/bin/* {path}')
    # os.system(f'cp /usr/x86_64-w64-mingw32/bin/libx264*.dll {path}')

    print('Copying files for Windows finished!', flush=True)


def build_windows_x264():
    print('Configuring X264 for Windows ...', flush=True)

    install_dir: str = os.path.abspath(f'ffmpeg/{X264_WINDOWS_DIR}')

    if not os.path.exists(X264_DIR):
        print('Cloning x264 repo ...', flush=True)
        subprocess.run(['git', 'clone', '--depth', '1', '--branch', 'stable', X264_REPO, X264_DIR], cwd='./')
    else:
        print('Cleaning x264 repo folder ...', flush=True)
        subprocess.run(['make', 'clean'], cwd=X264_DIR)

    if os.path.exists(install_dir):
        print(f'Removing existing x264 install directory: {install_dir}')
        shutil.rmtree(install_dir)
    os.makedirs(install_dir, exist_ok=True)

    x264_env = os.environ.copy()
    x264_env['CC'] = 'x86_64-w64-mingw32-gcc'
    x264_env['CXX'] = 'x86_64-w64-mingw32-g++'
    x264_env['AR'] = 'x86_64-w64-mingw32-ar'
    x264_env['RANLIB'] = 'x86_64-w64-mingw32-ranlib'
    x264_env['STRIP'] = 'x86_64-w64-mingw32-strip'
    x264_env['PKG_CONFIG'] = 'x86_64-w64-mingw32-pkg-config'

    cmd = [
        './configure',
        '--host=x86_64-w64-mingw32',
        '--cross-prefix=x86_64-w64-mingw32-',
        f'--prefix={install_dir}',
        '--enable-shared',
        '--disable-cli',
        '--enable-pic',
        '--disable-avs',
        '--extra-ldflags=-lpthread'
    ]

    subprocess.run(cmd, cwd=X264_DIR, env=x264_env, check=True)

    print('Compiling X264 ...', flush=True)

    subprocess.run(['make', f'-j{THREADS}'], cwd=X264_DIR, env=x264_env, check=True)
    subprocess.run(['make', 'install'], cwd=X264_DIR, env=x264_env, check=True)

    print('Compiling X264 finished!', flush=True)


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
