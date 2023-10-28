# Translations

At this stage we have a couple of different languages available inside of the editor. 

- English;
- Japanese;
- French;
- Dutch;
- Chinese;
- Polish;
- German.

## All languages welcome!

If you want to provide language support by entering your language or adjusting/adding to already existing languages, then please feel free to do so. No need to ask for permission. When adding/changing a language, please follow the guidelines bellow to create a smooth and effort free experience.

## How to contribute

Before contributing, you have to fork the Development branch of this repository and create a new branch called something like 'language_*language-code* update/addition'. Please refer to "New language" or "updating an already existing language" to know how to edit the JSON file correctly.

After you are done editing the JSON file you can create a pull request. Please only add the updated JSON file as we will handle the csv file and other project files.

### New language?

Run the python script "generate.py" by using "python generate.py" inside of the folder, select '2' and enter the official language code in plain text without any ' or " marks. Don't worry about the changes which need to be done inside any of the other project files as we will be adjusting those.

This will create a new entry for all keys inside of the JSON file, add the words next to the language code of each key and you're done!

### Updating an already existing language

In the translation.json file you'll find empty/prefilled slots for each key which needs translation. You can fill in or edit the current translation. Some text editors suport folding which may be helpful to only display the information which you want to see, but this is totally up to you.

## Nodes folder

We also have certain resources that change for languages. Inside of the nodes folder, copy one of each type, change the ending to your language code. Translate the inside of the scene and done.

# Future languages

We don't have any specific plans for adding more languages in the future. Language support will completely depend on the support of the community.

# Current contributors

- English: Voylin
- Japanese: Voylin
- French: Slander
- Dutch: Voylin
- Chinese: Aappaapp
- Polish: SzczurekYT
- German: Kiisu-Master
