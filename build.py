import os
import python.toolbox as toolbox
import translations.translations as translations
import gd_extensions.build_gdextensions as gde_extensions


def build_gozen():
    l_user_input = toolbox.get_input_choice('Menu', [
        'Full build (Godot, GDExtensions, Localizations, ...)',
        'Godot build only'])
    
    # Gather build info
    l_num_jobs = toolbox.get_input_jobs()

    l_platform = 'linux'
    match toolbox.get_input_choices('Select target platform', [
        'Linux',
        'Windows(Msys2)',
        'MacOS (not supported)']):
        case '2':
            l_platform = 'windows'
            scons_extra_args = 'use_mingw=yes'
        case '3': l_platform = 'macos'

    l_target = 'template_debug'
    match toolbox.get_input_choices('Select build target', [
        'template_debug',
        'template_release']):
        case '2': l_target = 'template_release'


    # Start building
    if user_input == 1:
        translations.generate_mo()
        gde_extensions.build_ffmpeg(l_num_jobs)

    print('Not yet to implemented!') # Building Godot application


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
