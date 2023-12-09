extends Node
## Settings Manager
##
## TODO: Make the actual settings menu a separate program which sends the
## data back to this script upon closing.

signal _on_settings_loaded
signal _on_project_saved

signal _on_window_mode_switch

signal _on_zen_switched(value)
signal _on_language_changed(value)


const PATH := "user://settings.dat"


var zen_mode: bool = false
var language: String = "en"


###############################################################
#region Data handlers  ########################################
###############################################################

func _ready() -> void:
	load_settings()


func load_settings() -> void:
	# Check to see if path actually exists
	if !FileAccess.file_exists(PATH):
		save_settings()
	
	# Open file and load data
	var file := FileAccess.open(PATH, FileAccess.READ)
	var data: Dictionary = file.get_var()
	for key: String in data:
		if get(key): # Check if variable still exists or not
			set(key, data[key])
	
	_on_settings_loaded.emit()


func save_settings() -> void:
	# Save the actual data
	var data: Dictionary = {}
	for x: Dictionary in get_property_list():
		if x.usage == 4096:
			data[x.name] = get(x.name)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_var(data, false)
	
	_on_project_saved.emit()

#endregion
###############################################################
#region Input handling  #######################################
###############################################################

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_zen_mode"):
		toggle_zen_mode()

#endregion
###############################################################

#     GETTERS AND SETTERS     #################################

###############################################################
#region Zen mode  #############################################
###############################################################

func get_zen_mode() -> bool:
	return zen_mode


func set_zen_mode(value: bool) -> void:
	zen_mode = value
	_on_zen_switched.emit(value)
	save_settings()


func toggle_zen_mode() -> void:
	set_zen_mode(!get_zen_mode())

#endregion
###############################################################
#region Language  #############################################
###############################################################

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
	language = language_code
	_on_language_changed.emit(language_code)
	save_settings()

#endregion
###############################################################
