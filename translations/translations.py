import sys
import os
import re

sys.path.append(os.path.join(os.path.dirname(os.path.realpath(__file__)),"../python"))
import toolbox



def generate_pot():
    # Go through files in 'src' (Exclude .godot and only look in *.tscn and *.gd files)
    # Make a dictionary of all entries, which line they appear on, msgctx from parameters
    # Generate file from dictionary
    print('not implemented yet')
    results = {}

    for root, _, files in os.walk('../src'):
        for file in files:
            if file.endswith(".tscn"):
                file_path = os.path.join(root, file)
                for block in _extract_blocks(file_path):
                    _parse_block(block, results, file_path)
    for key, value in results.items():
        print(key)
        for entry in value:
            print(f"    File: {entry['file_path']}, Block: {entry['block_number']}, Line: {entry['line_number']}")


def _extract_blocks(a_file_path):
    # For tscn files only
    with open(a_file_path, "r") as f:
        lines = f.readlines()
    
    blocks = []
    block_lines = []
    in_block = False

    for line_number, line in enumerate(lines, start=1):
        if '[node ' in line:
            if block_lines:
                blocks.append(block_lines)
                block_lines = []
            in_block = True
        elif line.strip() == '':
            in_block = False
        elif in_block:
            block_lines.append(line.strip())

    if block_lines:
        blocks.append(block_lines)
    
    return blocks


def _parse_block(a_block, a_results, a_file_path):
    # For tscn files only
    block_start_line = None
    auto_translate_false = False
    for line_number, line in enumerate(a_block, start=1):
        key, value = line.split('=', 1)
        key = key.strip()
        value = value.strip()
        
        if key == 'text' and not value.startswith('"') and not value.endswith('"'):
            block_start_line = line_number
        elif key == 'auto_translate' and value == 'false':
            auto_translate_false = True

    if block_start_line is not None and not auto_translate_false:
        text_value = a_block[0].split('=')[1].strip()
        if text_value not in a_results:
            a_results[text_value] = {'file_path': a_file_path, 'line_number': block_start_line}
    

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
        case 0: generate_pot()
        case 1: generate_mo()
        case 2: create_new_locale()


if __name__ == '__main__':
    toolbox.print_title('Translations')
    menu()
