import os
import python.toolbox as toolbox
import translations.translations as translations
import gd_extensions.build_gdextensions as gde_extensions



num_jobs = 0
platform = ''
scons_extra_args = ''
target = ''



def get_build_data():
    global num_jobs, platform, scons_extra_args, target

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



def build_gozen():
    pass


def menu():
    match toolbox.get_input_choice('Menu', [
        'Build GoZen',
        'Localization menu',
        'GDExtension menu']):
        case 0: build_gozen()
        case 1: translations.menu()
        case 2: gde_extensions.menu()


if __name__ == '__main__':
    toolbox.print_title('GoZen builder')
    menu()
