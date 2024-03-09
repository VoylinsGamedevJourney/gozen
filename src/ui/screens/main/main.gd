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
	if instance != null:
		Printer.error("Something went wrong! Can't have two 'screen_main' instances!")
		get_tree().quit(-1)
		return
	ScreenMain.instance = self
	
	var arguments := OS.get_cmdline_args()
	if arguments.size() == 2 and arguments[1].strip_edges().to_lower().contains(".gozen"):
		ProjectManager.load_project(arguments[1].strip_edges())
	else:
		%Content.add_child(preload("res://ui/screens/startup/startup.tscn").instantiate())


func close_startup() -> void:
	%Content.get_node("ScreenStartup").queue_free()


func open_settings_popup() -> void:
	# TODO: Make this work
	var popup: Window = preload(
		"res://ui/popups/settings_menu/settings_menu.tscn").instantiate()
	popup.name = "popup"
	add_child(popup)


func open_project_settings_popup() -> void:
	# TODO: Make this work
	var popup: Window = preload(
		"res://ui/popups/project_settings_menu/project_settings_menu.tscn").instantiate()
	popup.name = "popup"
	add_child(popup)
