extends Node
## Settings Manager

signal _on_settings_loaded

signal _on_window_mode_switch

signal _on_zen_switched(value)
signal _on_language_changed(value)


const PATH_SETTINGS := "user://settings.cfg"
const PATH_MENU_CFG := "user://settings_data.cfg"

var config := ConfigFile.new()

var dic: Dictionary

func _ready() -> void:
	print_system_data()
	load_defaults()
	load_settings()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_zen_mode"):
		set_zen_mode(!get_zen_mode())
		config.save(PATH_MENU_CFG)

################################################################
#region Startup  ###############################################
################################################################

func print_system_data() -> void:
	print_rich("[color=purple][b]GoZen Editor[/b][/color]")
	var info := [
		["Distribution", OS.get_distribution_name()],
		["OS Version", OS.get_version()],
		["Processor", OS.get_processor_name()],
		["Threads", OS.get_processor_count()],
		["Ram", "\n\tTotal: %s GB\n\tAvailable: %s GB" % [
				str("%0.2f" % (float(OS.get_memory_info().physical)/1_073_741_824)), 
				str("%0.2f" % (float(OS.get_memory_info().available)/1_073_741_824))]],
		["Video adapter", "\n\tName: %s\n\tVersion: %s\n\tType: %s" % [
				RenderingServer.get_video_adapter_name(),
				RenderingServer.get_video_adapter_api_version(),
				RenderingServer.get_video_adapter_type()]],
		
		["Debug build", OS.is_debug_build()],
		["GoZen version", ProjectSettings.get_setting("application/config/version")]
	]
	for x in info:
		print_rich("[b]%s:[/b] %s" % x)


func load_defaults() -> void:
	var settings := {
		"general": [
			"zen_mode",
			"language",
		], 
		"timeline": [
			"default_video_tracks",
			"default_audio_tracks",
		]
	}
	
	# Generate defaults + settings menu config file
	var settings_menu_config := ConfigFile.new()
	for section: String in settings:
		for setting: String in settings[section]:
			var setting_meta: Dictionary = call("get_%s_meta" % setting)
			call("set_%s" % setting, call("get_%s_meta" % setting).default)
			settings_menu_config.set_value(section, setting, setting_meta)
	settings_menu_config.save(PATH_MENU_CFG)


func load_settings() -> void:
	if !FileAccess.file_exists(PATH_SETTINGS):
		config.save(PATH_SETTINGS)
		_on_settings_loaded.emit()
		return
	# Load in user defined settings
	var user_config := ConfigFile.new()
	user_config.load(PATH_SETTINGS)
	for section: String in user_config.get_sections():
		for setting in user_config.get_section_keys(section):
			if config.has_section_key(section, setting):
				config.set_value(section, setting, user_config.get_value(section, setting))
	config.save(PATH_SETTINGS)
	_on_settings_loaded.emit()

#endregion
#################################################################
##
##      GETTERS AND SETTERS
##
#################################################################


################################################################
#region Zen Mode  ##############################################
################################################################

func set_zen_mode(new_value: bool) -> void:
	config.set_value("general", "zen_mode", new_value)
	_on_zen_switched.emit(new_value)


func get_zen_mode() -> bool:
	return config.get_value("general", "zen_mode", get_zen_mode_meta().default)


func get_zen_mode_meta() -> Dictionary:
	return {
		"default": false,
		"type": "bool"
	}

#endregion
################################################################
#region Language  ##############################################
################################################################

func set_language(new_value: String) -> void:
	if new_value not in get_language_meta().options:
		printerr("Invalid language value: '%s'!" % new_value)
		return
	config.set_value("general", "language", new_value)
	_on_language_changed.emit(new_value)


func get_language() -> String:
	return config.get_value("general", "language",  get_language_meta().default)


func get_language_meta() -> Dictionary:
	var options := {}
	for locale: String in TranslationServer.get_loaded_locales():
		options[locale] = TranslationServer.get_language_name(locale.split('_')[0])
	return {
		"default": "en",
		"options": options,
		"type": "text"
	}

#endregion
################################################################
#region Default Video Tracks  ##################################
################################################################

func set_default_video_tracks(new_value: int) -> void:
	config.set_value("general", "default_video_tracks", new_value)


func get_default_video_tracks() -> int:
	return config.get_value("general", "default_video_tracks",  get_default_video_tracks_meta().default)


func get_default_video_tracks_meta() -> Dictionary:
	return {
		"default": 3,
		"type": "int",
		"step": 1,
		"min_value": 1,
		"max_value": 30
	}

#endregion
################################################################
#region Default Audio Tracks  ##################################
################################################################

func set_default_audio_tracks(new_value: int) -> void:
	config.set_value("general", "default_audio_tracks", new_value)


func get_default_audio_tracks() -> int:
	return config.get_value("general", "default_audio_tracks",  get_default_audio_tracks_meta().default)


func get_default_audio_tracks_meta() -> Dictionary:
	return {
		"default": 3,
		"type": "int",
		"step": 1,
		"min_value": 1,
		"max_value": 30
	}

#endregion
################################################################
