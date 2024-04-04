import os
import shutil
import platform
import glob


def build_ffmpeg(num_jobs = 0):
    print('-= Compiling FFmpeg =-')

    if num_jobs == 0:
        print('Enter amount of cores/threads for compiling:')
        num_jobs = input('> ')

    os.chdir(os.path.dirname(os.path.realpath(__file__)))
    gdextension_dir = '../../src/bin/ffmpeg-bin'
    ffmpeg_source_folder = os.path.join(os.path.dirname(os.path.realpath(__file__)), 'ffmpeg')
    ffmpeg_bin_folder = os.path.join(os.path.dirname(os.path.realpath(__file__)), 'ffmpeg-bin')

    os.makedirs(gdextension_dir, exist_ok=True)
    os.makedirs(ffmpeg_bin_folder, exist_ok=True)
    os.chdir(ffmpeg_source_folder)

    config_extra_args = ''
    if platform.system().lower() == 'linux':
        os.environ['PATH'] = '/opt/bin:' + os.environ['PATH']
        cross_prefix = 'x86_64-w64-mingw32-'
        config_extra_args = '--cross-prefix=' + cross_prefix + ' --arch=x86_64 --target-os=mingw32'

    print('Configuring FFmpeg ...')
    os.system(f'./configure --prefix={ffmpeg_bin_folder} --enable-gpl --enable-shared {config_extra_args}')

    print('Building FFmpeg ...')
    os.system(f'make -j {num_jobs}')

    print('Installing ffmpeg ...')
    os.system(f'make -j {num_jobs} install')
    os.chdir('..')

    if platform.system().lower() == 'linux':
        print('Copying dlls to GDExtension dir ...')
        ffmpeg_dlls = os.path.join(ffmpeg_bin_folder, 'bin', '*.dll')
        for file in glob.glob(ffmpeg_dlls):
            shutil.copy(file, gdextension_dir)

        ## Copy dlls from /mingw64/bin
        #dll_path = '/usr/x86_64-w64-mingw32/bin/'
        #dlls = ['zlib1.dll', 'libiconv-2.dll', 'libbz2-1.dll', 'liblzma-5.dll', 'libwinpthread-1.dll']
        #for dll in dlls:
        #    shutil.copy(os.path.join(dll_path, dll), gdextension_dir)


if __name__ == '__main__':
    build_ffmpeg()
