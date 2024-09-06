#!/usr/bin/env python
import os
import platform as os_platform
import time


env = SConscript('gde_gozen/godot_cpp/SConstruct')
env.Append(CPPPATH=['src'])


jobs = ARGUMENTS.get('jobs', 4)
arch = ARGUMENTS.get('arch', 'x86_64')
target = ARGUMENTS.get('target', 'template_debug').replace('template_', '')
platform = ARGUMENTS.get('platform', 'linux')
recompile_ffmpeg = ARGUMENTS.get('recompile_ffmpeg', 'yes')

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
ffmpeg_args += f' --arch={arch}'


if 'linux' in platform:
    if ARGUMENTS.get('use_system', 'yes') == 'yes':  # For people who don't need the FFmpeg libs
        os.makedirs(f'bin/{platform}/{target}', exist_ok=True)

        env.Append(LINKFLAGS=['-static-libstdc++'])
        env.Append(CPPPATH=['/usr/include/ffmpeg/'])
        env.Append(LIBS=['avcodec', 'avformat', 'avdevice', 'avutil', 'swresample'])
    else:  # For people needing FFmpeg binaries
        platform += '_full'
        os.makedirs(f'bin/{platform}/{target}', exist_ok=True)
        if recompile_ffmpeg == 'yes':
            ffmpeg_args += ' --extra-cflags="-fPIC" --extra-ldflags="-fpic"'

            os.chdir('gde_gozen/ffmpeg')
            os.system('make distclean')
            time.sleep(2)

            os.system(f'./configure --prefix=./bin {ffmpeg_args} --target-os=linux')
            time.sleep(2)

            os.system(f'make -j {jobs}')
            os.system(f'make -j {jobs} install')
            os.chdir('../..')

        env.Append(LINKFLAGS=['-static-libstdc++'])
        env.Append(CPPFLAGS=['-Iffmpeg/bin', '-Iffmpeg/bin/include'])
        env.Append(LIBPATH=[
            'gde_gozen/ffmpeg/bin/include/libavcodec',
            'gde_gozen/ffmpeg/bin/include/libavformat',
            'gde_gozen/ffmpeg/bin/include/libavdevice',
            'gde_gozen/ffmpeg/bin/include/libavutil',
            'gde_gozen/ffmpeg/bin/include/libswresample',
            'gde_gozen/ffmpeg/bin/include/libswscale',
            'gde_gozen/ffmpeg/bin/lib'])

        print(os.system(f'cp gde_gozen/ffmpeg/bin/lib/*.so* bin/{platform}/{target}'))
        env.Append(LIBS=[
            'avcodec',
            'avformat',
            'avdevice',
            'avutil',
            'swresample',
            'swscale'])
elif 'windows' in platform:
    os.makedirs(f'bin/{platform}/{target}', exist_ok=True)
    if recompile_ffmpeg == 'yes':
        if os_platform.system().lower() == 'linux':
            ffmpeg_args += ' --cross-prefix=x86_64-w64-mingw32- --target-os=mingw32'
            ffmpeg_args += ' --enable-cross-compile'
            ffmpeg_args += ' --extra-ldflags="-static"'
            ffmpeg_args += ' --extra-cflags="-fPIC" --extra-ldflags="-fpic"'
        else:
            ffmpeg_args += ' --target-os=windows'

        os.chdir('gde_gozen/ffmpeg')
        os.system('make distclean')
        time.sleep(2)

        os.environ['PATH'] = '/opt/bin:' + os.environ['PATH']
        os.system(f'./configure --prefix=./bin {ffmpeg_args}')
        time.sleep(2)

        os.system(f'make -j {jobs}')
        os.system(f'make -j {jobs} install')
        os.chdir('../..')

    if os_platform.system().lower() == 'windows':
        env.Append(LIBS=[
            'avcodec.lib',
            'avformat.lib',
            'avdevice.lib',
            'avutil.lib',
            'swresample.lib',
            'swscale.lib'])
    else:
        env.Append(LIBS=[
            'avcodec',
            'avformat',
            'avdevice',
            'avutil',
            'swresample',
            'swscale'])

    env.Append(CPPPATH=['gde_gozen/ffmpeg/bin/include'])
    env.Append(LIBPATH=['gde_gozen/ffmpeg/bin/bin'])
    os.system(f'cp gde_gozen/ffmpeg/bin/bin/*.dll bin/{platform}/{target}')

CacheDir('.scons-cache')
Decider('MD5')

src = Glob('gde_gozen/src/*.cpp')
libpath = 'bin/{}/{}/libgozen{}{}'.format(platform, target, env['suffix'], env['SHLIBSUFFIX'])
sharedlib = env.SharedLibrary(libpath, src)
Default(sharedlib)
