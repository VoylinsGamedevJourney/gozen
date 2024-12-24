# Translations

> [!IMPORTANT]  
> GoZen is still in Alpha! Although translations are greatly appreciated, it's too early to know which strings of text will be used and that's why I request to wait until the beta stage is getting closer.

## Language contributors

- **Brazilian Portuguese:**
	- [Wilker-uwu](https://github.com/wilker-uwu)
- **Chinese:**
	- [Aappaapp](https://github.com/Aappaapp)
- **Dutch:**
	- [Voylin](https://github.com/Voylin)
- **English:**
	- [Voylin](https://github.com/Voylin)
- **French:**
	- [Slander](https://github.com/Therealslander)
	- [#Guigui](https://github.com/HastagGuigui)
- **German:**
	- [Kiisu-Master](https://github.com/Kiisu-Master)
- **Japanese:**
	- [Voylin](https://github.com/Voylin)
- **Polish:**
	- [SzczurekYT](https://github.com/SzczurekYT)
- **Russian:**
	- [Vovkiv](https://github.com/Vovkiv)
	- [USBashka](https://github.com/USBashka)
- **Ukrainian:**
	- [Vovkiv](https://github.com/Vovkiv)

## How to contribute

Before contributing, you have to [fork this repository](https://github.com/VoylinsGamedevJourney/GoZen/fork) and create a new branch called something like `language-*language-code*-update/init` (for example, `language-uk_UA-update` when you updating existing translation or `language-uk_UA-init` when you adding new one). Please refer to [Adding new translation](#adding-new-translation) or [Updating an already existing translation](#updating-an-already-existing-translation) to know how to create/edit the po file correctly.

When contributing with translations, please use [PoEdit](https://poedit.net/) or any other gettext tool. You can contribute by modifying the files in a text editor but will be quite troublesome.

### Adding new translation

When adding a new translation, open the translations_template.pot file with PoEdit. On the bottom you'll see a button to add a new language. Type in the language code and you are good to go to add the translations.

Be certain that you work with the latest version of the GoZen repository branch and that the language of your choice hasn't been added yet. A small tip for people using PoEdit, after creating the file, close it and open the po file directly with PoEdit as a message will popup allowing you to load the English po file to know what the original text is as the message ID's can be more difficult to figure out.

### Updating an already existing translation

Open the po file of the language you want to edit. You can find a list of language codes here in the [Godot docs](https://docs.godotengine.org/en/stable/tutorials/i18n/locales.html). When uncertain about a specific translation you can mark it as "Needs work", this allows other translators te see and check if your translation is correct or not.

