extends OptionButton


func _ready() -> void:
	for lang in SettingsManager.LANGUAGES:
		add_item(SettingsManager.LANGUAGES[lang][1], lang)
	selected = SettingsManager.language
	connect("item_selected", _item_selected)


func _item_selected(index: SettingsManager.LANGUAGE_ID) -> void:
	SettingsManager.language = index
	TranslationServer.set_locale(SettingsManager.LANGUAGES[index][0])

