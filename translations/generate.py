import yaml
import os
import collections


def main(yaml_file, csv_file):
  print("What would you like to do:")
  print("1. Generate main CSV file")
  print("2. Add a language code")
  command = input("> ")

  if command == "1":
    print("Generating main CSV file")
    generate_csv(yaml_file, csv_file)
  elif command == "2":
    print("Adding new language to YAML file")
    add_language(yaml_file)


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


def add_language(yaml_file):
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
  path = os.path.abspath(__file__)
  yaml_file = os.path.dirname(path) + "/locales.yaml"
  csv_file = os.path.dirname(path).replace("translations", "src/translations/translations.csv")
  main(yaml_file, csv_file)
