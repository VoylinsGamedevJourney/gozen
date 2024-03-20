class_name ScreenMain extends Control
## Screen Main
##
## This is the scene which gets loaded on startup. When opening GoZen it will
## check if opened with a ".gozen" path argument or not. Also contains the main
## overal structure for the GoZen Editor.

static var instance: ScreenMain


func _ready() -> void:
	## Setting the ScreenMain instance to the current node, this helps
	## other scripts to call show_screen and close_screen.
	ScreenMain.instance = self
	
	var arguments := OS.get_cmdline_args()
	if arguments.size() == 2 and Toolbox.check_extension(arguments[1], ["gozen"]):
		ProjectManager.load_project(arguments[1].strip_edges())
	else:
		%Content.add_child(preload("res://ui/screens/startup/startup.tscn").instantiate())
