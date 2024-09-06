import subprocess

# NOTE: You will need to compile the editor with 'dlink_enabled=yes' to have GDExtension support in web builds

if __name__ == '__main__':
    platform = 'linux'
    arch = 'x86_64'
    target = 'debug'
    extra_args = ''
    use_system = False

    print('-= GoZen GDExtension builder =-')
    print('Select platform:')
    print('1. Linux; (default)')
    print('2. Windows;')
    match input('> '):
        case '2': platform = 'windows'

    print('Select target:')
    print('1. Debug; (default)')
    print('2. Release.')
    match input('> '):
        case '2': target = 'release'
        case _: extra_args += ' dev_build=yes'

    if platform == 'linux':
        print('Use system FFmpeg:')
        print('1. Yes; (default)')
        print('2. No.')
        match input('> '):
            case '2': extra_args += ' use_system=no'
            case _:
                extra_args += ' use_system=yes'
                use_system = True

    if not use_system:
        print('Recompile FFmpeg:')
        print('1. Yes; (default)')
        print('2. No.')
        match input('> '):
            case '2': extra_args += ' recompile_ffmpeg=no'
            case _: extra_args += ' recompile_ffmpeg=yes'

    user_input = input('Number of threads/cores for compiling> ')
    if user_input.isdigit():
        jobs = int(user_input)
    else:
        jobs = 1

    subprocess.run(f'scons -j{jobs} target=template_{target} platform={platform} arch={arch} {extra_args}', shell=True, cwd='./')
