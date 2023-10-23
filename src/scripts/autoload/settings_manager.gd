extends Node
## Settings manager
##
## All settings are saved in a config file (INI)
## Settings list: (name, type, default)
## - zen_mode;  (bool, false)
## - language;  (String, "en")
## - update_notification;  (bool, true);
##
## These settings are saved inside of section 'main'

signal _settings_ready

signal _on_open_settings
signal _on_zen_switched(value)


const PATH := "user://settings.ini"
const DEFAULT := {
	language = "en",
	zen_mode = false,
	update_notification = true
}


var data: ConfigFile


func _ready() -> void:
	data = ConfigFile.new()
	if FileAccess.file_exists(PATH):
		_load()
	else:
		for setting in DEFAULT:
			data.set_value("main", setting, DEFAULT[setting])
	_settings_ready.emit()


func _load() -> void:
	data.load(PATH)
	for key in data.get_section_keys("main"):
		call("set_%s" % key, data.get_value("main", key), true)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_zen_mode"):
		toggle_zen_mode()


###############################################################
## Getters and setters  #######################################
###############################################################

## ZEN MODE  ##################################################

func get_zen_mode() -> bool:
	return data.get_value("main", "zen_mode", false)


func set_zen_mode(value: bool, startup: bool = false) -> void:
	data.set_value("main", "zen_mode", value)
	_on_zen_switched.emit(value)
	if !startup:
		data.save(PATH)


func toggle_zen_mode() -> void:
	set_zen_mode(!get_zen_mode())


## LANGUAGE  ##################################################

func get_language_list() -> Dictionary:
	var dic := {}
	var locales: Array = TranslationServer.get_loaded_locales()
	for locale in locales:
		var language_name: String = ""
		if locale.contains("_"):
			language_name += TranslationServer.get_language_name(locale.split('_')[0])
			language_name += " - %s" % TranslationServer.get_country_name(locale.split('_')[1])
		else:
			language_name = TranslationServer.get_language_name(locale)
		dic[locale] = language_name
	return dic


func set_language(language_code: String, startup: bool = false) -> void:
	TranslationServer.set_locale(language_code)
	data.set_value("main", "language", language_code)
	if !startup:
		data.save(PATH)


## UPDATE NOTIFICATION  #######################################

func get_update_notification() -> bool:
	return data.get_value("main", "update_notification", true)


func set_update_notification(value: bool, startup: bool = false) -> void:
	data.set_value("main", "update_notification", value)
	if !startup:
		data.save(PATH)
