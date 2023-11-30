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
  editor_config_file = os.path.dirname(path) + "/editor/project.godot"
  startup_config_file = os.path.dirname(path) + "/startup/project.godot"

  new_version = input("Version: ")
  print("Updating ...")
  update_version(editor_config_file, new_version)
  update_version(startup_config_file, new_version)

  print("Versions updated successfully!")