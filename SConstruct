#!/usr/bin/env python
import os
import platform as os_platform
import time


env = SConscript('godot_cpp/SConstruct')
env.Append(CPPPATH=['gde_gozen'])


platform = ARGUMENTS.get('platform', 'linux')
target = ARGUMENTS.get('target', 'template_debug').replace('template_', '')
jobs = ARGUMENTS.get('jobs', 4)
compile_ffmpeg = ARGUMENTS.get('compile_ffmpeg', 'false')

ffmpeg_args = '--enable-shared --enable-gpl'

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
    if compile_ffmpeg != 'false':
        os.chdir('ffmpeg')
        os.system(f'./configure --prefix=./bin {ffmpeg_args} --target-os=linux')
        time.sleep(4)

        os.system(f'make -j {jobs}')
        os.system(f'make -j {jobs} install')
        os.chdir('..')

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


    os.system(f'cp ffmpeg/bin/lib/lib*.so* bin/{platform}/{target}')
    env.Append(LIBS=['avcodec', 'avformat', 'avdevice', 'avutil', 'swresample', 'swscale'])
elif 'windows' in platform:
    if compile_ffmpeg != 'false':
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


src = Glob('gde_gozen/*.cpp')
libpath = 'bin/{}/{}/libgozen{}{}'.format(platform, target, env['suffix'], env['SHLIBSUFFIX'])
sharedlib = env.SharedLibrary(libpath, src)
Default(sharedlib)

