import os

from gozen_translations.generate_mo_files import generate_mo_files

num_jobs = 0
platform = ''
scons_extra_args = ''
target = ''


def main():
    print('-= GoZen Builder =-')

    choice = _print_choices('Select task', [
        'Build GoZen [Full]',
        'Generate localization',
        'Compile GDExtension [gozen_ffmpeg]'])

    if choice in ['1', '2']: # Generating localization
        generate_mo_files()
    
    if choice in ['1', '3']: # Compiling GDExtensions
        get_build_data()
        compile_gozen_ffmpeg()


def get_build_data():
    global num_jobs, platform, scons_extra_args, target

    print('-= Creating build profile =-')

    num_jobs = _print_choices('Enter amount of cores/threads for compiling')

    platform = _print_choices('Select target platform', [
        'Linux',
        'Windows(Msys2)',
        'MacOS (un-supported)'])

    match platform:
        case '1':
            platform = 'linux'
        case '2':
            platform = 'windows'
            scons_extra_args = 'use_mingw=yes'
        case '3':
            platform = 'macos'
        case _:
            print('Invalid platform choice, defaulting to Linux.')
            platform = 'linux'

    target = _print_choices('Select build target', [
        'template_debug',
        'template_release'])

    match target:
        case '2': target = 'template_release'
        case _:   target = 'template_debug'


def compile_gozen_ffmpeg():
    os.chdir('gd_extensions/gozen_ffmpeg')
    os.system(f'scons -j {num_jobs} target={target} platform={platform} {scons_extra_args}')
    os.chdir('../..')


def update_godot_cpp():
    print('Updating godot-cpp git ...')
    os.chdir('gd_extensions/godot_cpp')
    os.system('git pull')
    os.chdir('../..')


def _print_choices(title, tasks = []):
    print('\n-= ' + title + ': =-')
    for i, task in enumerate(tasks, start=1):
        print(f'{i}. {task};')
    user_input = input('> ')
    print('\n')
    return user_input


if __name__ == '__main__':
    main()
