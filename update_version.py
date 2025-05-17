import sys


def update_version(new_version: str):
    with open('src/project.godot', 'r', encoding='utf-8') as f:
        lines = f.readlines()

    for i, line in enumerate(lines):
        if line.strip().startswith('config/version'):
            lines[i] = f'config/version="{new_version}"\n'
            break

    with open('src/project.godot', 'w', encoding='utf-8') as f:
        f.writelines(lines)

    print(f'Version updated to {new_version} in "src/project.godot"')
    print('Full project.godot file:')
    for line in lines:
        print(line)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print('Usage: python update_version.py <new_version>')
    else:
        update_version(sys.argv[1])

