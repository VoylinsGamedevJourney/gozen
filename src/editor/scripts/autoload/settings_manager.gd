extends Node

signal _on_window_mode_switch







####   V OLD V

## Settings manager
##
## All settings are saved in a config file (INI)
## Settings list: (name, type, default)
## - zen_mode;  (bool, false)
## - language;  (String, "en")
## - update_notification;  (bool, true);
## - timeline_max_size; (int, 86400)
##
## These settings are saved inside of section 'main'


#region Signals
signal _settings_ready

signal _on_open_settings
signal _on_zen_switched(value)
signal _on_language_changed(value)
signal _on_update_notification_changed(value)
signal _on_timeline_max_size_changed(new_size)
#endregion


#region Constants
const PATH := "user://settings.ini"
#endregion


#region Settings data
var data : Settings
#endregion


func _ready() -> void:
	if FileAccess.file_exists(PATH):
		_load()
	else:
		data = Settings.new()
	_settings_ready.emit()


func _load() -> void:
	var settings_file := FileAccess.open(PATH, FileAccess.READ)
	var error := FileAccess.get_open_error()
	if error:
		printerr("Could not open settings file '%s'!\n\tError: %s" % [PATH, error])
	var data_string := settings_file.get_as_text()
	error = settings_file.get_error()
	if error:
		printerr("Could not save data to '%s'!\n\tError: %s" % [PATH, error])
	data = str_to_var(data_string)


func _save() ->void:
	var settings_file := FileAccess.open(PATH, FileAccess.WRITE)
	var error := FileAccess.get_open_error()
	if error:
		printerr("Could not open file '%s'!\n\tError: %s" % [PATH, error])
	settings_file.store_string(var_to_str(data))
	error = settings_file.get_error()
	if error:
		printerr("Could not save data to '%s'!\n\tError: %s" % [PATH, error])


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_zen_mode"):
		toggle_zen_mode()


###############################################################
#region Getters and setters  ##################################
###############################################################

#region ZEN MODE  #############################################

func get_zen_mode() -> bool:
	return data.zen_mode


func set_zen_mode(value: bool, startup: bool = false) -> void:
	data.zen_mode = value
	_on_zen_switched.emit(value)
	if !startup:
		data.save(PATH)


func toggle_zen_mode() -> void:
	set_zen_mode(!get_zen_mode())

#endregion

#region LANGUAGE  #############################################

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
	data.language = language_code
	_on_language_changed.emit(language_code)
	if !startup:
		_save()

#endregion

#region UPDATE NOTIFICATION  ##################################

func get_update_notification() -> bool:
	return data.update_notification


func set_update_notification(value: bool, startup: bool = false) -> void:
	data.update_notification = value
	_on_update_notification_changed.emit(value)
	if !startup:
		_save()

#endregion

#region TIMELINE MAXIMUM SIZE  ################################

func get_timeline_max_size() -> int:
	return data.timeline_max_size


func set_timeline_max_size(new_size: int, startup: bool = false) -> void:
	data.timeline_max_size = new_size
	_on_timeline_max_size_changed.emit(new_size)
	if !startup:
		data.save(PATH)

#endregion
#endregion
###############################################################
