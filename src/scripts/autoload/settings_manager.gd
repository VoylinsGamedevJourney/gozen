extends Node

signal _on_open_settings
signal _on_zen_switched(value)

signal _on_version_changed(new_version)
signal _on_version_outdated


const PATH := "user://settings"


var startup: bool = true
var settings: Settings = Settings.new()

var update_available: bool = false


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var data: String = FileManager.load_data(PATH)
	if data == "":
		save_settings()
		startup = false
		return
	settings = str_to_var(data)
	for setting in settings.get_property_list():
		if setting.usage == 4096:
			call("set_%s" % setting.name, settings.get(setting.name))
	startup = false


func save_settings() -> void:
	if !startup:
		FileManager.save_data(settings, PATH)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_zen_mode"):
		toggle_zen_mode()


##############################################################
# Getters and setters  #######################################
##############################################################

# ZEN MODE  ##################################################

func get_zen_mode() -> bool:
	return settings.zen_mode


func set_zen_mode(value: bool) -> void:
	settings.zen_mode = value
	_on_zen_switched.emit(value)
	save_settings()


func toggle_zen_mode() -> void:
	set_zen_mode(!get_zen_mode())


# LANGUAGE  ##################################################

func set_language(language_code: String) -> void:
	TranslationServer.set_locale(language_code)
	settings.language = language_code
	save_settings()


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



