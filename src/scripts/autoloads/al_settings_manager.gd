extends Node
# TODO: Stop using ConfigFile, there's a performance limitation

signal _on_language_changed(new_language: String)
signal _on_top_bar_positions_changed

var error: int = 0
var config: ConfigFile = ConfigFile.new()


func _ready() -> void:
	# Loading settings
	if FileAccess.file_exists(Globals.PATH_SETTINGS):
		error = config.load(Globals.PATH_SETTINGS)
		if error:
			printerr("Loading config returned error '%s'!" % error)
	
	TranslationServer.set_locale(get_language())
	get_viewport().set_embedding_subwindows(get_embed_subwindows())


func _save_settings() -> void:
	if config.save(Globals.PATH_SETTINGS):
		Printer.error(Globals.ERROR_CONFIG_SAVE)


#region #####################  Getters and setters  ############################

func get_language() -> String:
	return config.get_value("general", "language", "en")


func set_language(a_language: String) -> void:
	config.set_value("general", "language", a_language)
	TranslationServer.set_locale(a_language)
	
	_on_language_changed.emit(a_language)
	_save_settings()


func get_debug_enabled() -> bool:
	return config.get_value("general", "debug_enabled", true)


func set_debug_enabled(a_value: String) -> void:
	config.set_value("general", "debug_enabled", a_value)
	_save_settings()


func get_default_video_track_amount() -> int:
	return config.get_value("timeline", "default_video_tracks", 3)


func set_default_video_amount(a_default: int) -> void:
	config.set_value("timeline", "default_video_tracks", a_default)
	_save_settings()


func get_default_audio_amount() -> int:
	return config.get_value("timeline", "default_audio_tracks", 3)


func set_default_audio_amount(a_default: int) -> void:
	config.set_value("timeline", "default_audio_tracks", a_default)
	_save_settings()


func get_top_bar_menu_position(a_button_name: String) -> int:
	return config.get_value("top_bar", "button_%s" % a_button_name, 0)


func set_top_bar_menu_position(a_button_name: String, a_pos: int) -> void:
	# TODO: Add a way to change this through the settings menu.
	# Best way to do this is get all section keys from section "top_bar", check
	# if key starts with "button_". This way custom module buttons will also
	# show up in the list, and just add those entries dynamically to the
	# setings menu.
	# 0 = display in menu only
	# 1 = only next to editor button
	# 2 = display on both places
	config.set_value("top_bar", "button_%s" % a_button_name, a_pos)
	_save_settings()
	_on_top_bar_positions_changed.emit()


func get_embed_subwindows() -> bool:
	return config.get_value("viewport", "embed_subwindows", true)


func set_embed_subwindows(a_value: bool) -> void:
	get_viewport().set_embedding_subwindows(a_value)
	config.set_value("viewport", "embed_subwindows", a_value)
	_save_settings()

#endregion
