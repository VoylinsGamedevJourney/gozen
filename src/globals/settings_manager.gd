extends DataManager


signal _on_settings_saved
signal _on_settings_loaded

signal _on_window_moved
signal _on_window_resized
signal _on_window_mode_changed(mode: Window.Mode)

signal _on_icon_pack_changed


const PATH: String = "user://editor_settings"


var _tiling_wm: bool = false
var _resize_node: int = 0
var _moving_window: bool = false
var _move_offset: Vector2i = Vector2i.ZERO
var _prev_window_mode: Window.Mode = Window.MODE_MAXIMIZED
var _relative_mouse_pos: Vector2i = Vector2i.ZERO

var default_tracks: int = 6
var default_duration_image: int = 600
var default_duration_color: int = 600
var default_duration_gradient: int = 600
var default_duration_text: int = 600

var icon_pack: String = "default"

var max_actions: int = 200



#------------------------------------------------ GODOT FUNCTIONS
func _ready() -> void:
	GoZenServer.add_loadable(Loadable.new("Check for tiling wm", _check_tiling_wm))
	print_debug_info()
	load_data()


func _process(_delta: float) -> void:
	if _moving_window:
		if !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_moving_window = false
			_on_window_moved.emit()
			return
		get_window().position = DisplayServer.mouse_get_position() - _move_offset

	if _resize_node != 0:
		if !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_resize_node = 0
			_on_window_resized.emit()
			return

		_relative_mouse_pos = DisplayServer.mouse_get_position() - DisplayServer.window_get_position(get_window().get_window_id())
		if _resize_node & 1:
			get_window().size.x = _relative_mouse_pos.x+2
		if _resize_node & 2:
			get_window().size.y = _relative_mouse_pos.y+2

#------------------------------------------------ WINDOW HANDLING
func _check_tiling_wm() -> void:
	# I don't know enough about Windows for this
	if OS.get_name() == "Linux":
		match get_wm_name():
			"i3":
				_tiling_wm = true


func get_wm_name() -> String:
	var l_reply: Array = []
	if OS.execute("echo", ["$XDG_CURRENT_DESKTOP"], l_reply):
		printerr("Something went wrong getting XDG_CURRENT_DESKTOP")
		return ""
	var l_reply_string: String = l_reply[0]
	return l_reply_string.trim_suffix("\n")


func change_window_mode(a_mode: Window.Mode) -> void:
	if _tiling_wm:
		return

	_prev_window_mode = get_window().mode

	if a_mode == Window.MODE_MAXIMIZED and a_mode == get_window().mode:
		a_mode = Window.MODE_WINDOWED
	if a_mode == Window.MODE_FULLSCREEN and a_mode == get_window().mode:
		a_mode = _prev_window_mode

	get_window().mode = a_mode
	_on_window_mode_changed.emit(a_mode)
	

#------------------------------------------------ DATA HANDLING
func print_debug_info() -> void:
	print_rich("[color=purple][b]--==  GoZen - Video Editor  ==--")
	for l_info: Array in [
			["GoZen Version", ProjectSettings.get_setting("application/config/version")],
			["Distribution", OS.get_distribution_name()],
			["OS Version", OS.get_version()],
			["Processor", OS.get_processor_name()],
			["Threads", OS.get_processor_count()],
			["Ram", "\n\tTotal: %s GB\n\tAvailable: %s GB" % [
				str("%0.2f" % (OS.get_memory_info().physical/1_073_741_824)), 
				str("%0.2f" % (OS.get_memory_info().available/1_073_741_824))]],
			["Video adapter", "\n\tName: %s\n\tVersion: %s\n\tType: %s" % [
				RenderingServer.get_video_adapter_name(),
				RenderingServer.get_video_adapter_api_version(),
				RenderingServer.get_video_adapter_type()]],
			["Debug build", OS.is_debug_build()]]:
		print_rich("[color=purple][b]%s[/b] %s" % l_info)
	print_rich("[color=purple][b]--==--================--==--")


func save_data() -> void:
	if _save_data(PATH) == ERR_FILE_CANT_OPEN:
		printerr("Couldn't open settings file for saving! ", PATH)
	_on_settings_saved.emit()


func load_data() -> void:
	if _load_data(PATH) == ERR_FILE_CANT_OPEN:
		printerr("Couldn't open settings file for loading! ", PATH)
	_on_settings_loaded.emit()


#------------------------------------------------ ICON HANDLING
func change_icon_pack(l_pack_name: String) -> void:
	if !DirAccess.dir_exists_absolute("res://assets/icons/%s" % l_pack_name):
		printerr("No icon pack loaded named: ", l_pack_name)
		return

	icon_pack = l_pack_name
	_on_icon_pack_changed.emit()


func get_icon(l_icon_name: String) -> Texture2D:
	return load("res://assets/icons/%s/%s.png" % [icon_pack, l_icon_name])

