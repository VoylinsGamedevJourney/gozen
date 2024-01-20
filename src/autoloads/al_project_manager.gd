extends Node

var config: ConfigFile
var project_path: String


func load_project(path: String) -> void:
	if !path.to_lower().contains(".gozen"):
		Printer.error("Can't load project as path does not have '*.gozen' extension!")
		return
	if config == null:
		config = ConfigFile.new()
	if config.load(path):
		Printer.error("Could not open project file!")
		return
	project_path = path
