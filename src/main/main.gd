extends Control

@onready var label_window_title: Label = $TopBar/TopBarPanel/WindowTitleLabel

#region Window management variables
@onready var _windowed_size: Vector2i = get_window().size
@onready var _windowed_pos: Vector2i = get_window().position

var _previous_minimized_mode: Window.Mode = Window.MODE_MINIMIZED
var _previous_fullscreen_mode: Window.Mode = Window.MODE_FULLSCREEN

var move_window: bool = false
var move_window_offset: Vector2i

var window_mode: Window.Mode:
	get = get_window_mode, set = set_window_mode
#endregion
# Resize handling variables
var resizing: bool = false  ## Bool to check if currently resizing.
var resize_node: Control    ## Handle used for deciding how to resize.
var tiling: bool = false


func _ready() -> void:
	_check_startup_arguments()
	_check_tiling_window_manager()
	_setup_resize_handlers()
	
	
	# Window handling
	get_window().min_size = Vector2i(700,600)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# Window title
	label_window_title.text = tr("TEXT_UNTITLED_PROJECT_TITLE")
	ProjectManager._on_title_changed.connect(_on_project_title_changed)
	ProjectManager._on_unsaved_changes_changed.connect(_on_project_unsaved_changes_changed)


func _input(a_event: InputEvent) -> void:
	if a_event is InputEventKey:
		if a_event.keycode == KEY_F11 and a_event.pressed:
			toggle_fullscreen()


func _process(_delta: float) -> void:
	# Window dragging
	if move_window: 
		get_window().position = DisplayServer.mouse_get_position() - move_window_offset
	
	# Resize handling
	if resizing: 
		var l_window_pos: Vector2i = DisplayServer.window_get_position(get_window().get_window_id())
		var l_relative_mouse_pos: Vector2i = DisplayServer.mouse_get_position() - l_window_pos
		
		if resize_node in [$Bottom, $Corner]:
			get_window().size.y = l_relative_mouse_pos.y
		if resize_node in [$Right, $Corner]:
			get_window().size.x = l_relative_mouse_pos.x


func _notification(a_what: int) -> void:
	if a_what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		# if unminimizing, restore mode
		var l_windows_os: bool = Toolbox.os_is_windows()
		var l_not_minimized: bool = window_mode != Window.MODE_MINIMIZED
		
		if l_windows_os and l_not_minimized and _previous_minimized_mode != Window.MODE_MINIMIZED:
			set_window_mode(_previous_minimized_mode)


func _on_viewport_size_changed() -> void:
	if !tiling:
		var l_value: bool = window_mode == Window.MODE_WINDOWED and get_window().borderless
		$ResizeHandles.visible = l_value


func _check_startup_arguments() -> void:
	# Check if GoZen got opened with a path, if yes, load project, else show startup
	if OS.get_cmdline_args().size() == 2 and Toolbox.check_extension(OS.get_cmdline_args()[1], ["gozen"]):
		ProjectManager.load_project(OS.get_cmdline_args()[1].strip_edges())
		$Startup.queue_free()
	else: 
		$Startup.visible = true


func _check_tiling_window_manager() -> void:
	if OS.get_name() in ["Windows", "macOS"]:
		return # No tiling for these operating systems
	for l_de: String in ["SWAYSOCK", "I3SOCK"]:
		tiling = OS.has_environment(l_de)
		if tiling:
			$ResizeHandles.queue_free()
			return # Environment found so exit


func open_popup(a_popup: String) -> void:
	add_child(load("res://popups/{popup}/{popup}.tscn".format({popup = a_popup})).instantiate())


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
#region #####################  Top bar  ########################################

func _on_project_title_changed(a_title: String) -> void:
	# Extra space is needed for the '*' mark to indicate unsaved changes
	label_window_title.text = a_title + " "


func _on_project_unsaved_changes_changed(a_value: bool) -> void:
	label_window_title.text[-1] = "*" if a_value else " "


func _on_minimize_button_pressed() -> void:
	window_mode = Window.MODE_MINIMIZED


func _on_maximize_button_pressed() -> void:
	match window_mode:
		Window.MODE_WINDOWED:  window_mode = Window.MODE_MAXIMIZED
		Window.MODE_MAXIMIZED: window_mode = Window.MODE_WINDOWED

#endregion
#region #####################  Resize handling  ################################

func _setup_resize_handlers() -> void:
	for l_node: Node in [$ResizeHandles/Right, $ResizeHandles/Bottom, $ResizeHandles/Corner]:
		l_node.gui_input.connect(_on_resize_handler_input.bind(l_node))


func _on_resize_handler_input(a_event: InputEvent, a_node: Control) -> void:
	if a_event is InputEventMouseButton and a_event.button_index == 1:
		if !resizing:
			resize_node = a_node
		resizing = a_event.is_pressed()

#endregion
