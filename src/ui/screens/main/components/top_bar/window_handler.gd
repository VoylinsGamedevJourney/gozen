class_name TopBar extends PanelContainer
# When adding buttons, add the buttons next to the editor button, but also in
# the editor menu. Set the id and the function call in the variable dictionary
# menu_buttons. Also, set a default in the settings for the top bar.

static var instance

@onready var _windowed_win_size: Vector2i = get_window().size
@onready var _windowed_win_pos: Vector2i = get_window().position
var _pre_mz_mode: Window.Mode = Window.MODE_MINIMIZED
var _pre_fs_mode: Window.Mode = Window.MODE_FULLSCREEN

var move_window := false
var move_win_offset: Vector2i

var win_mode: Window.Mode:
	get: return get_window_mode()
	set(value): set_window_mode(value)


func _ready() -> void:
	instance = self
	get_viewport().size_changed.connect(func() -> void:
		var value := win_mode == Window.MODE_WINDOWED and get_window().borderless
		WindowResizeHandles.instance.visible = value)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_F11 and event.pressed:
			toggle_fullscreen()


func _process(_delta: float) -> void:
	if move_window: # Window dragging
		get_window().position = DisplayServer.mouse_get_position() - move_win_offset


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		# if unminimizing, restore mode
		if OS.get_name() == "Windows" and win_mode != Window.MODE_MINIMIZED and _pre_mz_mode != Window.MODE_MINIMIZED:
			win_mode = _pre_mz_mode


#region #####################  Window Mode  ####################################

func get_window_mode() -> Window.Mode:
	var window: Window = get_window()
	var current_mode = window.mode
	if OS.get_name() != "Windows" or !window.borderless:
		return current_mode
	if current_mode == Window.MODE_WINDOWED:
		var usable_screen := DisplayServer.screen_get_usable_rect(window.current_screen)
		if window.position == usable_screen.position and window.size == usable_screen.size:
			return Window.MODE_MAXIMIZED
		return Window.MODE_WINDOWED
	return current_mode


func set_window_mode(value: Window.Mode) -> void:
	if value == win_mode:
		return
	var window: Window = get_window()
	var prev_mode = win_mode
	if OS.get_name() != "Windows" or !window.borderless:
		window.mode = value
		return
	# store window size in windowed mode
	if prev_mode == Window.MODE_WINDOWED and _pre_mz_mode == Window.MODE_MINIMIZED:
		_windowed_win_pos = window.position
		_windowed_win_size = window.size
	if value == Window.MODE_MINIMIZED:
		_pre_mz_mode = prev_mode
	else:
		_pre_mz_mode = Window.MODE_MINIMIZED
	if value == Window.MODE_MAXIMIZED:
		window.borderless = false
		window.mode = Window.MODE_MAXIMIZED
		window.borderless = true
		# adjust mismatched window size and position
		var usable_screen := DisplayServer.screen_get_usable_rect(window.current_screen)
		window.position = usable_screen.position
		window.size = usable_screen.size + Vector2i(2, 2)
		return
	if value == Window.MODE_WINDOWED:
		window.borderless = false
		window.mode = prev_mode	# window.mode is not set to maximized when borderless
		window.mode = Window.MODE_WINDOWED
		window.borderless = true
		# restore window size and position
		window.size = _windowed_win_size
		window.position = _windowed_win_pos
		return
	window.mode = value


func toggle_fullscreen() -> void:
	if win_mode == Window.MODE_FULLSCREEN:
		win_mode = _pre_fs_mode
	else:
		_pre_fs_mode = win_mode
		win_mode = Window.MODE_FULLSCREEN

#endregion
#region #####################  Window Dragging  ################################

func _on_top_bar_dragging(event) -> void:
	if !event is InputEventMouseButton or event.button_index != 1:
		return # Only continues when event is mouse button 1 pressed
	var window: Window = get_window()
	var mouse_pos := DisplayServer.mouse_get_position()
	var win_pos := DisplayServer.window_get_position(window.get_window_id())
	move_window = false
	if win_mode != Window.MODE_WINDOWED:
		return
	if event.is_pressed():
		move_win_offset = mouse_pos - win_pos
		move_window = true
	elif OS.get_name() != "Windows":
		return
	var screen_rect := DisplayServer.screen_get_usable_rect(
		DisplayServer.SCREEN_WITH_MOUSE_FOCUS)
	var tb_top := Vector2i(mouse_pos.x, win_pos.y)
	var tb_bottom := Vector2i(mouse_pos.x, win_pos.y + int(size.y))
	if screen_rect.encloses(Rect2i(tb_top, tb_bottom)):
		return
	if tb_top.y < screen_rect.position.y:
		window.position = (
			tb_top.clamp(screen_rect.position, screen_rect.end)
			- Vector2i(move_win_offset.x, 0))
	else:
		window.position = (
			tb_bottom.clamp(screen_rect.position, screen_rect.end)
			- Vector2i(move_win_offset.x, int(size.y)))

#endregion
