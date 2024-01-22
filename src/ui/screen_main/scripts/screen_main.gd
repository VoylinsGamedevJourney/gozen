class_name ScreenMain extends Control

enum SCREENS { STARTUP, SETTINGS, PROJECT_SETTINGS }

static var instance: ScreenMain


func _ready() -> void:
	# Setting the ScreenMain instance to the current node, this helps
	# other scripts to call show_screen and close_screen.
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
		# If Overlay is active, another screen is already open,
		# so we can't open the new screen.
		Printer.error("Can't open screen as another one is still open!")
		return
	%Overlay.visible = true
	var screen: Resource
	
	if screen_id == SCREENS.STARTUP:
		screen = load("res://ui/screen_startup/screen_startup.tscn")
	elif screen_id == SCREENS.SETTINGS:
		screen = preload("res://ui/screen_settings/screen_settings.tscn")
	elif screen_id == SCREENS.PROJECT_SETTINGS:
		screen = preload("res://ui/screen_project_settings/screen_project_settings.tscn")
	
	$VBox/Content.add_child(screen.instantiate())


func close_screen() -> void:
	%Overlay.visible = false
	get_child(-1).queue_free()
