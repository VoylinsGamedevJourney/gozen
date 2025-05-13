# GoZen Translations 🌍
Translations for GoZen are community maintained, contributions to help making GoZen more accessible to a wider audience are always appreciated.

This document outlines the current status of translations and how you can contribute.

## Language status
We use [Gettext PO files](https://www.gnu.org/software/gettext/manual/html_node/PO-Files.html) for translations. The source strings (in English) are located in the `gozen.pot`.

### Actively maintained languages ✅
| Language             | Code    | Maintainer(s)                               |
| -------------------- | ------- | ------------------------------------------- |
| English (Source)     | `en`    | [Voylin](https://github.com/voylin)         |
| Chinese (Simplified) | `zh_CN` | [Aappaapp](https://github.com/Aappaapp)     |
| Dutch                | `nl`    | [Voylin](https://github.com/Voylin)         |
| French               | `fr`    | [Slander](https://github.com/Slander), [#Guigui](https://github.com/HastagGuigui) |
| Japanese             | `ja`    | [Voylin](https://github.com/Voylin)         |
| Polish               | `pl`    | [SzczurekYT](https://github.com/SzczurekYT) |

### Languages needing maintainers ⚠️
| Language             | Code    |
| -------------------- | ------- |
| Brazilian Portuguese | `pt_BR` |
| German               | `de`    |
| Russian              | `ru`    |
| Ukrainian            | `uk`    |

This list of languages is from entries which have been made but don't have any active maintainers anymore.

## How to contribute 🛠️

Before contributing, you have to [fork this repository](https://github.com/VoylinsGamedevJourney/GoZen-translations/fork) and create a new branch called something like `language-*language-code*-update` (for example, `language-uk_UA-update` when you updating existing translation or `language-uk_UA-addition` when you adding new one). Please refer to [Adding new translation](#adding-new-translation) or [Updating an already existing translation](#updating-an-already-existing-translation) to know how to create/edit the po file correctly.

When contributing with translations, please use [Poedit](https://poedit.net/) or any other gettext tool. You can contribute by modifying the files in a text editor but will be quite troublesome.

After you are done creating/editing the po file you can create a pull request, after which we will check and merge it when approved.

### Adding new translation

When adding a new translation, open the translations_template.pot file with Poedit. On the bottom you'll see a button to add a new language. Type in the language code and you are good to go to add the translations.

Be certain that you work with the latest version of the template file and that the language of your choice hasn't been added yet. A small tip for people using Poedit, after creating the file, close it and open the po file directly with Poedit as a message will popup allowing you to load the English po file to know what the original text is as the message ID's can be more difficult to figure out.

### Updating an already existing translation

Open the po file of the language you want to edit. You can find a list of language codes here in the [Godot docs](https://docs.godotengine.org/en/stable/tutorials/i18n/locales.html). When uncertain about a specific translation you can mark it as "Needs work", this allows other translators te see and check if your translation is correct or not.

