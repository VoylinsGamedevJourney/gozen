extends Node

var config : ConfigFile


# Called when the node enters the scene tree for the first time.
func _ready():
	Printer.startup()
	config = ConfigFile.new()
	config.load(ProjectSettings.get_setting("globals/path/settings"))
