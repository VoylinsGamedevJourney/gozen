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


###############################################################
#region Setting: Language  ####################################
###############################################################

func get_language() -> String:
	return config.get_value("general", "language", "en")


func set_language(new_language: String) -> void:
	config.set_value("general", "language", new_language)
	_on_language_changed.emit(new_language)
	TranslationServer.set_locale(new_language)
	save_settings()

#endregion
###############################################################
