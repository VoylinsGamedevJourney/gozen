extends Node
## Settings Manager
##
## All settings getters and setters are inside this autoload.
## All variables which are added to settings should have their
## setters and getters put here.

signal _on_open_settings
signal _on_zen_switched(value)


enum LANGUAGE {
	ENGLISH, 
	JAPANESE, 
	FRENCH, 
	DUTCH, 
	CHINESE_TAIWAN, 
	POLISH,
}


const LANGUAGE_INFO := {
	LANGUAGE.ENGLISH: {
		locale = "en",
		language = "English",
	},
	LANGUAGE.JAPANESE: {
		locale = "ja",
		language = "日本語",
	},
	LANGUAGE.FRENCH: {
		locale = "fr",
		language = "Français"
	},
	LANGUAGE.DUTCH: {
		locale = "nl",
		language = "Nederlands"
	},
	LANGUAGE.CHINESE_TAIWAN: {
		locale = "zh_TW",
		language = "中文"
	},
	LANGUAGE.POLISH: {
		locale = "pl_pl",
		language = "Polski"
	},
}

const PATH := "user://settings"


var settings: Settings = Settings.new()
var startup := true


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var data: String = FileManager.load_data(PATH)
	if data == "":
		startup = false
		save_settings()
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
	if event.is_action_pressed("switch_zen_mode"):
		set_zen_mode(!get_zen_mode())


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

# LANGUAGE  ##################################################

func set_language(language: LANGUAGE) -> void:
	TranslationServer.set_locale(LANGUAGE_INFO[language].locale)
	settings.language = language
	save_settings()
