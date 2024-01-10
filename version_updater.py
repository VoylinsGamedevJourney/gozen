import os
import re


def update_version(config_path, new_version):
  with open(config_path, 'r') as file:
    content = file.read()
  content = re.sub(r'(config/version=)"[^"]+"', r'\1"{}"'.format(new_version), content)
  with open(config_path, 'w') as file:
    file.write(content)


if __name__ == "__main__":
  path = os.path.abspath(__file__)
  editor_config_file = os.path.dirname(path) + "/src/editor/project.godot"
  startup_config_file = os.path.dirname(path) + "/src/startup/project.godot"
  settings_menu_config_file = os.path.dirname(path) + "/src/settings_menu/project.godot"

  new_version = input("Version: ")
  print("Updating ...")
  update_version(editor_config_file, new_version)
  update_version(startup_config_file, new_version)
  update_version(settings_menu_config_file, new_version)

  stable = input("Stable (Y/n): ")
  if stable.lower() == "y" or stable.lower() == "yes":
    print("Updating stable file ...")
    with open('STABLE_VERSION', 'w') as file:
      file.write(new_version)

  print("Versions updated successfully!")