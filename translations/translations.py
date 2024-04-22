import sys
import os
import re

sys.path.append(os.path.join(os.path.dirname(os.path.realpath(__file__)),'../python'))
import toolbox



def generate_pot():
    # Go through files in 'src' (Exclude .godot and only look in *.tscn and *.gd files)
    # Make a dictionary of all entries, which line they appear on, msgctx from parameters
    # Generate file from dictionary
    results = {}
    files_list = []

    for root, _, files in os.walk('../src'):
        for file in files:
            if file.endswith('.tscn'):
                _scan_tscn_file(os.path.join(root, file), results, files_list)

    # For testing only
    #for key, value in results.items():
    #    print(key)
    #    #for entry in value:
    #    #    print(f'    File: {entry['file_path']}, Block: {entry['block_number']}, Line: {entry['line_number']}')
    with open('translations_template.pot', 'w') as file:
        file.write('# LANGUAGE translation for GoZen - Video Editor for the following files:\n')
        for file_path in sorted(files_list):
            file.write(f'# {file_path.replace("../src", "res:/")}\n')
        file.write('#, fuzzy\nmsgid ""\nmsgstr ""\n')
        file.write('"Project-Id-Version: GoZen - Video Editor\\n"\n')
        file.write('"MIME-Version: 1.0\\n"\n')
        file.write('"Content-Type: text/plain; charset=UTF-8\\n"\n')
        file.write('"Content-Transfer-Encoding: 8-bit\\n"\n')
        for key, value in results.items():
            file.write('\n')
            file.write(f'#: {value["file_path"].replace("../src", "res:/")}:{value["line_number"]}\n')
            file.write(f'#: node={value["node_type"]}, type = {value["text_type"]}\n')
            file.write(f'msgid "{key}"\nmsgstr ""\n')







def _scan_tscn_file(a_file_path, a_results, a_files_list):
    with open(a_file_path, 'r') as f:
        lines = f.readlines()
    
    node_type = ''
    text = ''
    text_line_number = ''
    tooltip_text = ''
    tooltip_text_line_number = ''
    auto_translate = True
    for line_number, line in enumerate(lines, start=1):
        if '[node' in line:
            temp_node_type = re.search(r'type="([^"]+)"', line)
            if temp_node_type:
                node_type = temp_node_type.group(1)
        
        if line.startswith("text = "):
            text = re.search(r'text = "([^"]+)"', line).group(1)
            text_line_number = line_number
        elif line.startswith("tooltip_text = "):
            text = re.search(r'tooltip_text = "([^"]+)"', line).group(1)
            tooltip_text_line_number = line_number
        elif line.startswith("auto_translate = "):
            auto_translate = re.search(r'auto_translate = ([^"]+)', line).group(1) != 'false'

        if line == '\n':
            # Block ended
            if auto_translate and node_type != '':
                if a_file_path not in a_files_list:
                    a_files_list.append(a_file_path)
                if text != '':
                    a_results[text] = {
                        'file_path': a_file_path, 
                        'line_number': text_line_number, 
                        'node_type': node_type,
                        'text_type': 'text'}
                elif tooltip_text != '':
                    a_results[tooltip_text] = {
                        'file_path': a_file_path, 
                        'line_number': tooltip_text_line_number, 
                        'node_type': node_type,
                        'text_type': 'tooltip_text'}
            node_type = ''
            text = ''
            text_line_number = ''
            tooltip_text = ''
            tooltip_text_line_number = ''
            auto_translate = True


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
