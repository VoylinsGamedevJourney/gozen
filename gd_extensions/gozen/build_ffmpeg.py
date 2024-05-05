import sys
import os
import shutil
import platform
import glob

sys.path.append(os.path.join(os.path.dirname(os.path.realpath(__file__)),"../../python"))
import toolbox



folder_bin = os.path.join(os.path.dirname(os.path.realpath(__file__)), '../../bin/ffmpeg_bin')
folder_source = os.path.join(os.path.dirname(os.path.realpath(__file__)), 'ffmpeg')



def configure_ffmpeg():
    config_extra_args = ''
    if platform.system().lower() == 'linux':
        os.environ['PATH'] = '/opt/bin:' + os.environ['PATH']
        cross_prefix = 'x86_64-w64-mingw32-'
        config_extra_args = '--cross-prefix=' + cross_prefix + ' --arch=x86_64 --target-os=mingw32'
    
    os.system(f'{folder_source}/configure --prefix={folder_bin} --enable-gpl --enable-shared {config_extra_args}')


def make_ffmpeg(a_num_jobs):
    os.makedirs(folder_bin, exist_ok=True)
    os.system(f'make -j {a_num_jobs}')
    os.system(f'make -j {a_num_jobs} install')


def build(a_num_jobs = 0):
    if a_num_jobs == 0: # Getting threads/cores for compiling FFmpeg
        a_num_jobs = toolbox.get_input_jobs()

    configure_ffmpeg() # Configuring FFmpeg build
    make_ffmpeg(a_num_jobs) # Building ffmpeg
        


if __name__ == '__main__':
    toolbox.print_title('FFmpeg builder')
    build()
