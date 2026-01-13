class_name EditorUI
extends Control
# TODO: Add a proxy workflow

static var instance: EditorUI


@export var menu_bar: HBoxContainer
@export var screen_tab_container: TabContainer

var screen_buttons: Array[Button] = []



func _ready() -> void:
	instance = self

	# Populate screen_buttons.
	for node: Node in menu_bar.get_children():
		if node is Button:
			screen_buttons.append(node)

	switch_screen(0)
	print_startup_info()
	InputManager.on_show_editor_screen.connect(switch_screen.bind(0))
	InputManager.on_show_render_screen.connect(switch_screen.bind(1))
	InputManager.on_show_subtitle_screen.connect(switch_screen.bind(2))
	InputManager.on_switch_screen.connect(switch_screen_quick)
	PhysicsServer2D.set_active(false)
	PhysicsServer3D.set_active(false)

	_check_startup_args()
	add_child(preload(Library.SCENE_STARTUP).instantiate())

	CommandManager.register(
			"command_render_menu", switch_screen.bind(1), "open_render_screen")
	

func _check_startup_args() -> void:
	# Check if editor got opened with a project path as argument.
	for arg: String in OS.get_cmdline_args():
		if arg.to_lower().ends_with(Project.EXTENSION):
			Project.open(arg)
			return


func print_startup_info() -> void:
	Print.header_editor("--==  GoZen - Video Editor  ==--")

	for info_print: PackedStringArray in [
			["GoZen Version", ProjectSettings.get_setting("application/config/version")],
			["OS", OS.get_model_name()],
			["OS Version", OS.get_version()],
			["Distribution", OS.get_distribution_name()],
			["Processor", OS.get_processor_name()],
			["Threads", OS.get_processor_count()],
			["Ram", "\n\tTotal: %s GB\n\tAvailable: %s GB" % [
				str("%0.2f" % (OS.get_memory_info().physical/1_073_741_824)), 
				str("%0.2f" % (OS.get_memory_info().available/1_073_741_824))]],
			["Video adapter", "\n\tName: %s\n\tVersion: %s\n\tType: %s" % [
				RenderingServer.get_video_adapter_name(),
				RenderingServer.get_video_adapter_api_version(),
				RenderingServer.get_video_adapter_type()]],
			["Locale", OS.get_locale()],
			["Startup args", OS.get_cmdline_args()]]:
		Print.info_editor(info_print[0], info_print[1])

	Print.header_editor("--==--================--==--")


func switch_screen(index: int) -> void:
	if RenderManager.encoder == null or !RenderManager.encoder.is_open():
		screen_tab_container.current_tab = index
		screen_buttons[index].button_pressed = true


func switch_screen_quick() -> void:
	if RenderManager.encoder == null or !RenderManager.encoder.is_open():
		if !screen_tab_container.select_next_available():
			screen_tab_container.current_tab = 0
		screen_buttons[screen_tab_container.current_tab].button_pressed = true

