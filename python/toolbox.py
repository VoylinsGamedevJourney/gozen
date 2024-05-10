import readline


def print_title(a_title):
    print(f'--== {a_title} ==--')


def get_input_choice(a_title, a_choices):
    print(f'-= {a_title} =-')
    for i, choice in enumerate(a_choices, start=1):
        print(f'{i}. {choice};')

    user_input = ''
    while True:
        user_input = input('> ')
        if user_input.isdigit() and int(user_input) <= len(a_choices):
            break
        elif user_input == '':
            user_input = 1
            break
        print('Please enter a valid number!')
    print()
    return int(user_input) - 1


def get_input_jobs():
    user_input = ''
    print('-= Enter nr of threads/cores for compiling =-')
    while True:
        user_input = input('> ')
        if user_input.isdigit():
            break
        elif user_input == '':
            user_input = 0
            break
        print('Please enter a valid number!')
    print()
    return int(user_input) - 1


def get_platform_choice():
    match get_input_choice('Select target platform', [
            'Linux',
            'Windows(Msys2)',
            'MacOS (not supported)']):
        case 0:
            return 'linux'
        case 1: return 'windows'
        case 2: return 'macos'


def get_target_choice():
    match get_input_choice('Select build target', [
            'template_debug',
            'template_release']):
        case 0: return 'template_debug'
        case 1: return 'template_release'
