#!/usr/bin/env python
import os
import platform as os_platform
import time


env = SConscript('godot_cpp/SConstruct')
env.Append(CPPPATH=['gde_gozen'])


platform = ARGUMENTS('platform', 'linux')
target = ARGUMENTS.get('target', 'template_debug').replace('template_', '')
jobs = ARGUMENTS.get('jobs', 4)


ffmpeg_args = '--disable-shared --enable-gpl --enable-static'

ffmpeg_args += ' --disable-postproc'
ffmpeg_args += ' --disable-avfilter'
ffmpeg_args += ' --disable-programs --disable-ffmpeg --disable-ffplay --disable-ffprobe'
ffmpeg_args += ' --disable-doc --disable-htmlpages --disable-manpages --disable-podpages --disable-txtpages'
ffmpeg_args += ' --disable-network'

ffmpeg_args += ' --enable-libx264 --enable-libx265'
ffmpeg_args += ' --enable-libvorbis'
ffmpeg_args += ' --enable-libopus'
ffmpeg_args += ' --enable-libdav1d'
ffmpeg_args += ' --enable-libtheora'
ffmpeg_args += ' --enable-libwebp'

ffmpeg_args += ' --quiet'
ffmpeg_args += ' --arch={}'.format(ARGUMENTS.get('arch', 'x86_64'))


os.makedirs(f'bin/{platform}/{target}', exist_ok=True)


if 'linux' in platform:
    env.Append(LINKFLAGS=['-static-libstdc++'])
    env.Append(CPPFLAGS=['-Iffmpeg/bin', '-Iffmpeg/bin/include'])
    env.Append(LIBPATH=[
        'ffmpeg/bin/include/libavcodec',
        'ffmpeg/bin/include/libavformat',
        'ffmpeg/bin/include/libavdevice',
        'ffmpeg/bin/include/libavutil',
        'ffmpeg/bin/include/libswresample',
        'ffmpeg/bin/include/libswscale',
        'ffmpeg/bin/lib'])

    os.chdir('ffmpeg')
    ffmpeg_args += ' --extra-cflags="-fPic" --extra-ldflags="-fpic"'
    os.system(f'./configure --prefix=./bin {ffmpeg_args} --target-os=linux')
    time.sleep(4)

    os.system(f'make -j {jobs}')
    os.system(f'make -j {jobs} install')
    os.chdir('..')

    env.Append(LIBS=['avcodec', 'avformat', 'avdevice', 'avutil', 'swresample', 'swscale'])
    os.system(f'cp ffmpeg/bin/lib/lib*.so* bin/{platform}/{target}')
elif 'windows' in platform:
    if os_platform.system().lower() == 'linux':
        ffmpeg_args += ' --cross-prefix=x86_64-w64-mingw32- --target-os=mingw32'
        ffmpeg_args += ' --enable-cross-compile'
        ffmpeg_args += ' --extra-ldflags="-static"'
    else:
        ffmpeg_args += ' --target-os=windows'

    os.chdir('ffmpeg')
    os.environ['PATH'] = '/opt/bin:' + os.environ['PATH']
    os.system(f'./configure --prefix=./bin {ffmpeg_args}')
    time.sleep(4)

    os.system(f'make -j {jobs}')
    os.system(f'make -j {jobs} install')
    os.chdir('..')

    if os_platform.system().lower() == 'windows':
        env.Append(LIBS=[
            'avcodec.lib',
            'avformat.lib',
            'avdevice.lib',
            'avutil.lib',
            'swresample.lib',
            'swscale.lib'])
    else:
        env.Append(LIBS=['avcodec', 'avformat', 'avdevice', 'avutil', 'swresample', 'swscale'])

    env.Append(CPPPATH=['ffmpeg/bin/include'])
    env.Append(LIBPATH=['ffmpeg/bin/bin'])

    os.system(f'cp ffmpeg/bin/bin/*.dll bin/{platform}/{target}')
    src = Glob('src/*.cpp')


libpath = 'bin/{}/{}/lib{}{}{}'.format(platform, target, libname, env['suffix'], env['SHLIBSUFFIX'])
sharedlib = env.SharedLibrary(libpath, src)
Default(sharedlib)

