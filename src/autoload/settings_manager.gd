extends Node
# After changing a variable, save_settings needs to be run

enum LANGUAGE {
	ENGLISH, 
	JAPANESE, 
	FRENCH, 
	DUTCH, 
	CHINESE_TAIWAN,
	POLISH }

const PATH := "user://settings"

var zen_mode: bool = false:
	set(x):
		zen_mode = x
		Globals._on_zen_switch.emit()
		save_settings()
var language: LANGUAGE = LANGUAGE.ENGLISH:
	set(x):
		var locale: String
		match x:
			LANGUAGE.ENGLISH: locale = "en"
			LANGUAGE.JAPANESE: locale = "ja"
			LANGUAGE.FRENCH: locale = "fr"
			LANGUAGE.DUTCH: locale = "nl"
			LANGUAGE.CHINESE_TAIWAN: locale = "zh_TW"
			LANGUAGE.POLISH: locale = "pl_pl"
		TranslationServer.set_locale(locale)

var module_settings := {}


# Load settings only at startup
func _ready() -> void:
	if !FileAccess.file_exists(PATH): save_settings()
	var file := FileAccess.open(PATH, FileAccess.READ)
	var data: Dictionary = file.get_var()
	for key in data: set(key, data[key])


func save_settings() -> void:
	var data := {}
	for key in get_property_list():
		if key.usage == 4096: data[key.name] = get(key.name)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_var(data)
