extends Node

signal _on_language_changed(new_language: String)


var config := ConfigFile.new()


# Called when the node enters the scene tree for the first time.
func _ready():
	Printer.startup() # Printing some debug info
	load_settings()


func load_settings() -> void:
	if FileAccess.file_exists(ProjectSettings.get_setting("globals/path/settings")):
		config.load(ProjectSettings.get_setting("globals/path/settings"))
	
	# Setting necesarry settings
	TranslationServer.set_locale(get_language())


func save_settings() -> void:
	config.save(ProjectSettings.get_setting("globals/path/settings"))


#################################################################
##
##      GETTERS AND SETTERS
##
#################################################################


###############################################################
#region Setting: Language  ####################################
###############################################################

func get_language() -> String:
	return config.get_value("general", "language", "en")


func set_language(new_language: String) -> void:
	config.set_value("general", "language", new_language)
	TranslationServer.set_locale(new_language)
	_on_language_changed.emit(new_language)
	save_settings()

#endregion
###############################################################
#region Setting: Default video tracks  ########################
###############################################################

func get_default_video_tracks() -> int:
	return config.get_value("timeline", "default_video_tracks", 3)


func set_default_video_tracks(new_default: int) -> void:
	config.set_value("timeline", "default_video_tracks", new_default)
	save_settings()

#endregion
###############################################################
#region Setting: Default audio tracks  ########################
###############################################################

func get_default_audio_tracks() -> int:
	return config.get_value("timeline", "default_audio_tracks", 3)


func set_default_audio_tracks(new_default: int) -> void:
	config.set_value("timeline", "default_audio_tracks", new_default)
	save_settings()

#endregion
###############################################################
