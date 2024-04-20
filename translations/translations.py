import sys
import os

sys.path.append(os.path.join(os.path.dirname(os.path.realpath(__file__)),"../python"))
import toolbox



def generate_pot():
    # Go through files in 'src' (Exclude .godot and only look in *.tscn and *.gd files)
    # Make a dictionary of all entries, which line they appear on, msgctx from parameters
    # Generate file from dictionary
    print('not implemented yet')


def generate_mo():
    file_path = os.path.join(os.path.dirname(__file__))
    for po_file in os.listdir(os.path.join(file_path, 'po_files')):
        if not po_file.endswith('.po'): continue
        mo_file = os.path.join(file_path, '../src/translations/', po_file[:-3] + '.mo')
        os.system(f'msgfmt -o {mo_file} {file_path}/po_files/{po_file}')


def create_new_locale():
    # Ask for locale (Use toolbox and check against possible locales to see if correct)
    # Generate new po file with POT file
    print('not implemented yet')


def menu():
    match toolbox.get_input_choice('Localization menu', [
        'Generate POT',
        'Generate *.mo files',
        'Add new locale']):
        case 1: generate_pot()
        case 2: generate_mo()
        case 3: create_new_locale()


if __name__ == '__main__':
    toolbox.print_title('Translations')
    menu()
