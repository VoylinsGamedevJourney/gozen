import os


from gozen_translations.generate_mo_files import generate_mo_files



def compile_gdextension():
    print('-= Compiling GDExtension =-')

    # Entering gd_extensions folder
    current_dir = os.getcwd()
    os.chdir(os.path.join(current_dir, 'gd_extensions'))

    print('Checking submodule for godot_cpp ...')
    os.chdir('godot_cpp')
    os.system('git pull')
    os.chdir('../gozen_ffmpeg')

    # Determine number of jobs
    print('Enter amount of cores/threads for compiling:')
    num_jobs = input('> ')

    # Select target platform
    print('Select target platform:')
    print('1. Linux;')
    print('2. Windows(Msys2);')
    platform = input('> ')
    scons_extra_args = ''

    if platform == '1':
        platform = 'linux'
    elif platform == '2':
        platform = 'windows'
        scons_extra_args = 'use_mingw=yes'
    else:
        print('Invalid platform choice, defaulting to Linux.')
        platform = 'linux'

    # Select build target
    print('Select build target:')
    print('1. template_debug;')
    print('2. template_release;')
    target = input('> ')

    if target == '2':
        target = 'template_release'
    else:
        target = 'template_debug'

    # Compile GDExtension
    os.system(f'scons -j {num_jobs} target={target} platform={platform} {scons_extra_args}')


def main():
    print('-= GoZen Builder =-')

    print('-= Select task =-')
    print('1. Build GoZen [full]')
    print('2. Build GoZen [light]')
    print('3. Generate localization')
    print('4. Compile GDExtension')
    choice = input('> ')

    if choice in ['1', '2', '3']: # Generating localization
        print('Checking git gozen_translations')
        os.chdir('gozen_translations')
        os.system('git pull')
        os.chdir('..')

        generate_mo_files()
    
    if choice in ['1', '2', '4']: # Compiling GDExtension
        compile_gdextension()


if __name__ == '__main__':
    main()
