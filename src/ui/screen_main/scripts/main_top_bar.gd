extends PanelContainer

###############################################################
#region Window Mode  ##########################################
###############################################################

@export var resize_handles: Control

var _windowed_win_size: Vector2i = Vector2i(300, 100)
var _windowed_win_pos: Vector2i = Vector2i(0, 0)
var _win_mode: Window.Mode = Window.MODE_WINDOWED

var win_mode: Window.Mode:
	get:
		return _win_mode

	set(value):
		if value == _win_mode: return

		# store prev_mode and current win_mode
		var prev_mode = _win_mode
		_win_mode = value

		if OS.get_name() != "Windows" or !get_window().borderless:
			get_window().mode = value
			return

		# store window size in windowed mode
		if prev_mode == Window.MODE_WINDOWED:
			_windowed_win_pos = get_window().position
			_windowed_win_size = get_window().size

		if value == Window.MODE_MAXIMIZED:
			get_window().borderless = false
			get_window().mode = Window.MODE_MAXIMIZED
			get_window().borderless = true
			
			# adjust mismatched window size and position
			var usable_screen := DisplayServer.screen_get_usable_rect(get_window().current_screen)
			get_window().position = usable_screen.position + Vector2i(1, 1)
			get_window().size = usable_screen.size
			return

		if value == Window.MODE_WINDOWED:
			get_window().borderless = false
			get_window().mode = prev_mode	# window.mode is not set to maximized when borderless
			get_window().mode = Window.MODE_WINDOWED
			get_window().borderless = true
			
			# restore window size and position
			get_window().size = _windowed_win_size
			get_window().position = _windowed_win_pos
			return

		get_window().mode = value

#endregion
###############################################################
#region Main  #################################################
###############################################################

var move_window := false
var move_start: Vector2i


func _ready() -> void:
	$Margin/HBox/ProjectButton.visible = false
	ProjectManager._on_project_loaded.connect(func(): 
		$Margin/HBox/ProjectButton.visible = true)

	assert(resize_handles, "Resize handles not assigned.")
	get_viewport().size_changed.connect(func():
		resize_handles.visible = win_mode == Window.MODE_WINDOWED and get_window().borderless
	)

#endregion
###############################################################
#region Window Dragging  ######################################
###############################################################

func _on_top_bar_dragging(event):
	if event is InputEventMouseButton and event.button_index == 1:
		move_window = event.is_pressed() and win_mode == Window.MODE_WINDOWED
		if move_window:
			move_start = get_viewport().get_mouse_position()


func _process(_delta: float) -> void:
	if move_window:
		var mouse_delta = Vector2i(get_viewport().get_mouse_position()) - move_start
		get_window().position += mouse_delta

#endregion
###############################################################
#region Top Bar Window Buttons  ###############################
###############################################################

func _on_minimize_button_pressed():
	win_mode = Window.MODE_MINIMIZED


func _on_switch_mode_button_pressed():
	if win_mode == Window.MODE_WINDOWED:
		win_mode = Window.MODE_MAXIMIZED
	else:
		win_mode = Window.MODE_WINDOWED


func _on_exit_button_pressed():
	if ProjectManager.project_path == "":
		get_tree().quit()
		return
	var dialog := ConfirmationDialog.new()
	dialog.canceled.connect(func(): get_tree().quit())
	dialog.confirmed.connect(func():
			ProjectManager.save_project()
			get_tree().quit())
	dialog.ok_button_text = tr("DIALOG_TEXT_SAVE")
	dialog.cancel_button_text = tr("DIALOG_TEXT_DONT_SAVE")
	dialog.borderless = true
	dialog.dialog_text = tr("DIALOG_TEXT_ON_EXIT")
	get_tree().root.add_child(dialog)
	dialog.popup_centered()

#endregion
###############################################################
#region Top Bar Setting Buttons  ##############################
###############################################################

func _on_project_button_pressed():
	ScreenMain.instance.show_screen(ScreenMain.SCREENS.PROJECT_SETTINGS)


func _on_settings_button_pressed():
	ScreenMain.instance.show_screen(ScreenMain.SCREENS.SETTINGS)

#endregion
###############################################################
