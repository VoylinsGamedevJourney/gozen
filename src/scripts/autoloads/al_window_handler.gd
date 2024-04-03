extends PanelContainer
# When adding buttons, add the buttons next to the editor button, but also in
# the editor menu. Set the id and the function call in the variable dictionary
# menu_buttons. Also, set a default in the settings for the top bar.

@onready var _windowed_size: Vector2i = get_window().size
@onready var _windowed_pos: Vector2i = get_window().position
var _previous_minimized_mode: Window.Mode = Window.MODE_MINIMIZED
var _previous_fullscreen_mode: Window.Mode = Window.MODE_FULLSCREEN

var move_window: bool = false
var move_window_offset: Vector2i

var window_mode: Window.Mode:
	get = get_window_mode, set = set_window_mode


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _input(a_event: InputEvent) -> void:
	if a_event is InputEventKey:
		if a_event.keycode == KEY_F11 and a_event.pressed:
			toggle_fullscreen()


func _process(_delta: float) -> void:
	if move_window: # Window dragging
		get_window().position = DisplayServer.mouse_get_position() - move_window_offset


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		# if unminimizing, restore mode
		var l_windows_os: bool = Toolbox.os_is_windows()
		var l_not_minimized: bool = window_mode != Window.MODE_MINIMIZED
		
		if l_windows_os and l_not_minimized and _previous_minimized_mode != Window.MODE_MINIMIZED:
			set_window_mode(_previous_minimized_mode)


func _on_viewport_size_changed() -> void:
	var l_value: bool = window_mode == Window.MODE_WINDOWED and get_window().borderless
	WindowResizeHandles.instance.visible = l_value


#region #####################  Window Mode  ####################################

func get_window_mode() -> Window.Mode:
	var l_window: Window = get_window()
	
	if !Toolbox.os_is_windows() or !l_window.borderless:
		return l_window.mode
	
	if l_window.mode == Window.MODE_WINDOWED:
		var l_usable_screen: Rect2i = DisplayServer.screen_get_usable_rect(l_window.current_screen)
		
		if l_window.position == l_usable_screen.position and l_window.size == l_usable_screen.size:
			return Window.MODE_MAXIMIZED
		return Window.MODE_WINDOWED
	return l_window.mode


func set_window_mode(a_value: Window.Mode) -> void:
	if a_value == window_mode:
		return
	
	if !Toolbox.os_is_windows() or !get_window().borderless:
		get_window().mode = a_value
		return
	
	# store window size in windowed mode
	if window_mode == Window.MODE_WINDOWED and _previous_minimized_mode == Window.MODE_MINIMIZED:
		_windowed_pos = get_window().position
		_windowed_size = get_window().size
	
	if a_value == Window.MODE_MINIMIZED:
		_previous_minimized_mode = window_mode
	else:
		_previous_minimized_mode = Window.MODE_MINIMIZED
	
	if a_value == Window.MODE_MAXIMIZED:
		get_window().borderless = false
		get_window().mode = Window.MODE_MAXIMIZED
		get_window().borderless = true
		# adjust mismatched window size and position
		var l_usable_screen: Rect2i = DisplayServer.screen_get_usable_rect(get_window().current_screen)
		get_window().position = l_usable_screen.position
		get_window().size = l_usable_screen.size + Vector2i(2, 2)
		return
	
	if a_value == Window.MODE_WINDOWED:
		get_window().borderless = false
		get_window().mode = window_mode # window.mode is not set to maximized when borderless
		get_window().mode = Window.MODE_WINDOWED
		get_window().borderless = true
		# restore window size and position
		get_window().size = _windowed_size
		get_window().position = _windowed_pos
		return
	
	get_window().mode = a_value


func toggle_fullscreen() -> void:
	if window_mode == Window.MODE_FULLSCREEN:
		set_window_mode(_previous_fullscreen_mode)
	else:
		_previous_fullscreen_mode = window_mode
		set_window_mode(Window.MODE_FULLSCREEN)


func _on_exit_request() -> void:
	if ProjectManager.project_path == "":
		get_tree().quit()
		return
	
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	
	dialog.canceled.connect(func() -> void: get_tree().quit())
	dialog.confirmed.connect(func() -> void:
			ProjectManager.save_project()
			get_tree().quit())
	dialog.ok_button_text = tr("DIALOG_TEXT_SAVE")
	dialog.cancel_button_text = tr("DIALOG_TEXT_DONT_SAVE")
	dialog.borderless = true
	dialog.dialog_text = tr("DIALOG_TEXT_ON_EXIT")
	
	get_tree().root.add_child(dialog)
	dialog.popup_centered()


#endregion
#region #####################  Window Dragging  ################################

func _on_top_bar_dragging(event: InputEvent) -> void:
	if !event is InputEventMouseButton or event.button_index != 1:
		return # Only continues when event is mouse button 1 pressed
	
	var l_mouse_pos: Vector2i = DisplayServer.mouse_get_position()
	var l_window_pos: Vector2i = DisplayServer.window_get_position(get_window().get_window_id())
	
	move_window = false
	if window_mode != Window.MODE_WINDOWED:
		return
	
	if event.is_pressed():
		move_window_offset = l_mouse_pos - l_window_pos
		move_window = true
	elif !Toolbox.os_is_windows():
		return
	
	var l_screen_rect := DisplayServer.screen_get_usable_rect(DisplayServer.SCREEN_WITH_MOUSE_FOCUS)
	var l_topbar_top: Vector2i = Vector2i(l_mouse_pos.x, l_window_pos.y)
	var l_topbar_bottom: Vector2i = Vector2i(l_mouse_pos.x, l_window_pos.y + int(size.y))
	
	if l_screen_rect.encloses(Rect2i(l_topbar_top, l_topbar_bottom)):
		return
	
	if l_topbar_top.y < l_screen_rect.position.y:
		get_window().position = (
			l_topbar_top.clamp(l_screen_rect.position, l_screen_rect.end) - Vector2i(move_window_offset.x, 0))
	else:
		get_window().position = (
			l_topbar_bottom.clamp(l_screen_rect.position, l_screen_rect.end) - Vector2i(move_window_offset.x, int(size.y)))

#endregion
