import json
import os



def main(json_file, csv_file):
  print("What would you like to do:")
  print("1. Generate main CSV file")
  print("2. Add a language code")
  command = input("> ")

  if command == "1":
    print("Generating main CSV file")
    generate_csv(json_file, csv_file)
  elif command == "2":
    print("Adding new language to JSON")
    add_language(json_file)


def generate_csv(json_file, csv_file):
  try:
    with open(json_file, 'r') as file:
      data = json.load(file)

    languages = list(data[next(iter(data))].keys())
    header = "KEY," + ",".join(languages) + "\n"

    with open(csv_file, 'w') as file:
      file.write(header)
      for key, values in data.items():
        row = f"{key}," + ",".join(['"{}"'.format(values.get(lang, '')) for lang in languages]) + "\n"
        file.write(row)
  except Exception as e:
    print(f"An error occurred: {e}")


def add_language(json_file):
  locale = input("Enter locale code: ")
  try:
    with open(json_file, 'r') as file: data = json.load(file)
    for k in data.keys(): data[k][locale] = ""
    with open(json_file, 'w') as file: json.dump(data, file, indent=2, ensure_ascii=False)
  except Exception as e:
    print(f"An error occurred: {e}")


if __name__ == "__main__":
  path = os.path.abspath(__file__)
  json_file = os.path.dirname(path) + "/locales.json"
  csv_file = os.path.dirname(path).replace("translations", "src/translations/translations.csv")
  main(json_file, csv_file)

