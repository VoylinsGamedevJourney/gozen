extends Node

signal language_changed


enum LANGUAGE_ID { ENGLISH, JAPANESE, FRENCH, DUTCH }
const LANGUAGES := {
	LANGUAGE_ID.ENGLISH: ["en", "English"],
	LANGUAGE_ID.JAPANESE: ["ja", "日本語"], 
	LANGUAGE_ID.FRENCH: ["fr", "Français"], 
	LANGUAGE_ID.DUTCH: ["nl", "Nederlands"] } 
var language := LANGUAGE_ID.ENGLISH: set = _set_language

@export var custom_module_settings := {}


func _ready() -> void:
	print(TranslationServer.get_locale())
	load_settings()
	print(TranslationServer.get_locale())


func save_settings() -> void:
	var settings_file := FileAccess.open_compressed(Globals.PATH_SETTINGS, FileAccess.WRITE)
	var settings_data := {}
	for setting in get_property_list():
		if setting.usage == 4096: 
			settings_data[setting.name] = get(setting.name)
	settings_file.store_var(settings_data)


func load_settings() -> void:
	var settings_file := FileAccess.open_compressed(Globals.PATH_SETTINGS, FileAccess.READ)
	if settings_file == null: return
	var settings_data: Dictionary = settings_file.get_var()
	settings_file.close()
	for setting in settings_data:
		set(setting, settings_data[setting])


func _set_language(new_language: LANGUAGE_ID) -> void:
	language = new_language
	TranslationServer.set_locale(LANGUAGES[language][0])
	emit_signal("language_changed")
	save_settings()
