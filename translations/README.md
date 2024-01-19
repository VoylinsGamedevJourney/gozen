## Translations

At this stage we have a couple of different languages available inside of the editor:

- Brazilian Portuguese by: Wilker-uwu
- Chinese by: Aappaapp
- Dutch by: Voylin
- English by: Voylin
- French by: Slander, #Guigui
- German by: Kiisu-Master
- Japanese by: Voylin
- Polish by: SzczurekYT
- Russian by: Vovkiv
- Ukrainian by: Vovkiv

## How to contribute

Before contributing, you have to [fork this repository](https://github.com/VoylinsGamedevJourney/GoZen-translations/fork) and create a new branch called something like `language-*language-code*-update` (for example, `language-uk_UA-update` when you updating existing translation or `language-uk_UA-addition` when you adding new one). Please refer to [Adding new translation](#adding-new-translation) or [Updating an already existing translation](#updating-an-already-existing-translation) to know how to edit the YAML file correctly.

After you are done editing the YAML file you can create a pull request. Please only add the updated YAML file as we will handle the csv file and other project files.

### Adding new translation

Run the python script `generate.py` by using `python generate.py` inside of the folder, select `2` and enter the official language code (for list of language codes, refer to [Godot docs](https://docs.godotengine.org/en/stable/tutorials/i18n/locales.html)) in plain text without any `'` or `"` marks . Don't worry about the changes which need to be done inside any of the other project files as we will be adjusting those.

This will create a new entry for all keys inside of the YAML file, add the words next to the language code of each key and you're done!

### Updating an already existing translation

In the `translation.yaml` file you'll find empty/prefilled slots for each key which needs translation. You can fill in or edit the current translation. Some text editors support folding which may be helpful to only display the information which you want to see, but this is totally up to you.