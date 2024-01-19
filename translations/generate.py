import yaml
import os
import collections


def main():
  # Getting file paths
  path = os.path.abspath(__file__)

  yaml_file_editor = os.path.dirname(path) + "/locales_editor.yaml"
  yaml_file_startup = os.path.dirname(path) + "/locales_startup.yaml"
  yaml_file_settings_menu = os.path.dirname(path) + "/locales_settings_menu.yaml"
  
  csv_file_editor = os.path.dirname(path).replace("translations", "src/editor/translations/translations.csv")
  csv_file_startup = os.path.dirname(path).replace("translations", "src/startup/translations/translations.csv")
  csv_file_settings_menu = os.path.dirname(path).replace("translations", "src/settings_menu/translations/translations.csv")

  # Showing option menu + waiting for input
  print("What would you like to do:")
  print("1. Generate main CSV files")
  print("2. Add a language code to YAML files")
  command = input("> ")

  # Command functions
  if command == "1":    # Generate CSV
    print("Generating CSV files ...")
    generate_csv(yaml_file_editor, csv_file_editor)
    generate_csv(yaml_file_startup, csv_file_startup)
    generate_csv(yaml_file_settings_menu, csv_file_settings_menu)
  elif command == "2":  # New locale
    print("Adding new language to YAML files ...")
    add_new_language(yaml_file_editor)
    add_new_language(yaml_file_startup)
    add_new_language(yaml_file_settings_menu)
  print("Finished!")



def generate_csv(yaml_file, csv_file):
  try:
    with open(yaml_file, 'r', encoding="utf8") as file:
      data = yaml.safe_load(file)

    languages = list(data[next(iter(data))].keys())
    header = "KEY," + ",".join(languages) + "\n"

    with open(csv_file, 'w', encoding="utf8") as file:
      file.write(header)
      for key, values in data.items():
        row = f"{key}," + ",".join(['"{}"'.format(values.get(lang, '')) for lang in languages]) + "\n"
        file.write(row)
  except Exception as e:
    print(f"An error occurred: {e}")


def add_new_language(yaml_file):
  locale = input("Enter locale code: ")
  try:
    with open(yaml_file, 'r', encoding="utf8") as file:
      data = file.readlines()

    new_data = []
    key = ""
    for line in data:
      if line[0] == ' ':
        new_data.append(line)
      else:
        if key != '':
          new_data.append("  " + locale + ": \"\"\n")
        key = line
        new_data.append(line)
    new_data.append("  " + locale + ": \"\"\n")

    with open(yaml_file, 'w', encoding="utf8") as file:
      file.writelines(new_data)
  except Exception as e:
    print(f"An error occurred: {e}")


if __name__ == "__main__":
  main()
