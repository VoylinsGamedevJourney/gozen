class_name ScreenMain extends Control

enum SCREENS { STARTUP, SETTINGS, PROJECT_SETTINGS }

static var instance: ScreenMain


func _ready() -> void:
	## Setting the ScreenMain instance to the current node, this helps
	## other scripts to call show_screen and close_screen.
	ScreenMain.instance = self
	
	var arguments := OS.get_cmdline_args()
	if arguments.size() == 2 and arguments[1].to_lower().contains(".gozen"):
		Printer.todo("Make the project load on startup when GoZen is started with *.gozen file path.")
		# TODO:
		#  When starting up the project with a file path, load the project directly
	else:
		show_screen(SCREENS.STARTUP)


func show_screen(screen_id: SCREENS) -> void:
	if %Overlay.visible:
		if screen_id == SCREENS.SETTINGS:
			# Settings menu can be opened on top of other screens
			$VBox/Content.get_children()[-1].visible = false
		else:
			$VBox/Content.get_children()[-1].queue_free()
		$VBox/Content.get_children()[-1].visible = true
	%Overlay.visible = true
	var screen: Resource
	
	if screen_id == SCREENS.STARTUP:
		screen = load("res://ui/screen_startup/screen_startup.tscn")
	elif screen_id == SCREENS.SETTINGS:
		screen = preload("res://ui/screen_settings_menu/screen_settings_menu.tscn")
	elif screen_id == SCREENS.PROJECT_SETTINGS:
		screen = preload("res://ui/screen_project_settings_menu/screen_project_settings_menu.tscn")
	
	$VBox/Content.add_child(screen.instantiate())


func close_screen() -> void:
	# This means that there is a screen above a screen
	# so overlay should stay visible
	%Overlay.visible = %Content.get_child(-2).name != "Overlay"
	%Content.get_child(-1).queue_free()
