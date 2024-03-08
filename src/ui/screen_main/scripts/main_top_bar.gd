extends PanelContainer
# When adding buttons, add the buttons next to the editor button, but also in
# the editor menu. Set the id and the function call in the variable dictionary
# menu_buttons. Also, set a default in the settings for the top bar.

var menu_buttons := []

var move_window := false
var move_win_offset: Vector2i


func _ready() -> void:
	set_default_menu_buttons()
	# TODO: Fetch all custom module buttons
	set_button_positions()
	
	%TopMenuButtons.get_node("ProjectSettingsButton").visible = false
	ProjectManager._on_project_loaded.connect(func(): 
		%TopMenuButtons.get_node("ProjectSettingsButton").visible = true)
	
	assert(resize_handles, "Resize handles not assigned.")
	get_viewport().size_changed.connect(func():
		resize_handles.visible = win_mode == Window.MODE_WINDOWED and get_window().borderless
	)


###############################################################
#region Window Mode  ##########################################
###############################################################

@export var resize_handles: Control

@onready var _windowed_win_size: Vector2i = get_window().size
@onready var _windowed_win_pos: Vector2i = get_window().position

var win_mode: Window.Mode:
	get:
		var current_mode = get_window().mode
		if OS.get_name() != "Windows" or !get_window().borderless:
			return current_mode

		if current_mode == Window.MODE_WINDOWED:
			var usable_screen := DisplayServer.screen_get_usable_rect(get_window().current_screen)
			if get_window().position == usable_screen.position and get_window().size == usable_screen.size:
				return Window.MODE_MAXIMIZED
			return Window.MODE_WINDOWED

		return current_mode

	set(value):
		if value == win_mode: return

		var prev_mode = win_mode

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
			get_window().position = usable_screen.position
			get_window().size = usable_screen.size + Vector2i(2, 2)
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
#region Window Dragging  ######################################
###############################################################

func _on_top_bar_dragging(event) -> void:
	if event is InputEventMouseButton and event.button_index == 1:
		var mouse_pos := DisplayServer.mouse_get_position()
		var win_pos := DisplayServer.window_get_position(get_window().get_window_id())
		move_window = false

		if win_mode == Window.MODE_WINDOWED:
			if event.is_pressed():
				move_win_offset = mouse_pos - win_pos
				move_window = true

			elif OS.get_name() == "Windows":
				var screen_rect := DisplayServer.screen_get_usable_rect(
					DisplayServer.SCREEN_WITH_MOUSE_FOCUS
				)
				var tb_top := Vector2i(mouse_pos.x, win_pos.y)
				var tb_bottom := Vector2i(mouse_pos.x, win_pos.y + int(size.y))

				if !screen_rect.encloses(Rect2i(tb_top, tb_bottom)):
					if tb_top.y < screen_rect.position.y:
						get_window().position = (
							tb_top.clamp(screen_rect.position, screen_rect.end)
							- Vector2i(move_win_offset.x, 0)
						)
					else:
						get_window().position = (
							tb_bottom.clamp(screen_rect.position, screen_rect.end)
							- Vector2i(move_win_offset.x, int(size.y))
						)

func _process(_delta: float) -> void:
	if move_window:
		get_window().position = DisplayServer.mouse_get_position() - move_win_offset

#endregion
###############################################################
#region Top Bar Window Buttons  ###############################
###############################################################

func _on_minimize_button_pressed() -> void:
	win_mode = Window.MODE_MINIMIZED


func _on_switch_mode_button_pressed() -> void:
	if win_mode == Window.MODE_WINDOWED:
		win_mode = Window.MODE_MAXIMIZED
	else:
		win_mode = Window.MODE_WINDOWED


func _on_exit_button_pressed() -> void:
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
#region Top Bar Buttons  ######################################
###############################################################

func set_default_menu_buttons() -> void:
	%TopEditorButton.get_popup().id_pressed.connect(func(id: int):
		menu_buttons[id].function.call())
	SettingsManager._on_top_bar_positions_changed.connect(set_button_positions)
	add_menu_button( # Project settings
		"res://assets/icons/movie_edit.png",
		"Project settings",
		_on_project_button_pressed,
		"todo: tooltip")
	add_menu_button( # Settings
		"res://assets/icons/settings_video_camera.png",
		"Settings",
		_on_settings_button_pressed,
		"todo: tooltip")
	if !SettingsManager.config.has_section("top_bar"):
		SettingsManager.set_top_bar_menu_position("project_settings", 1)
		SettingsManager.set_top_bar_menu_position("settings", 1)
	elif !SettingsManager.config.get_section_keys("top_bar").has("button_project_settings"):
		SettingsManager.set_top_bar_menu_position("project_settings", 1)
	elif !SettingsManager.config.get_section_keys("top_bar").has("button_settings"):
		SettingsManager.set_top_bar_menu_position("settings", 1)
	add_separator("Modular entries")


func add_menu_button(icon_path: String, title: String, function: Callable, tooltip: String) -> void:
	var icon: Texture2D = Texture2D.new()
	icon = load(icon_path)
	
	menu_buttons.append({
		"icon": icon,
		"title": title,
		"function": function,
		"tooltip": tooltip
	})
	var button := Button.new()
	button.custom_minimum_size = Vector2i(26,26)
	button.name = "%sButton" % title.capitalize().replace(" ", "")
	button.tooltip_text = tooltip
	button.icon = icon
	button.expand_icon = true
	button.pressed.connect(function)
	%TopMenuButtons.add_child(button)


func add_separator(title: String) -> void:
	menu_buttons.append(title)


func set_button_positions() -> void:
	var menu: PopupMenu = %TopEditorButton.get_popup()
	menu.clear()
	for id in menu_buttons.size():
		if menu_buttons[id] is String:
			menu.add_separator(menu_buttons[id])
			continue
		var key: String = menu_buttons[id].title.to_lower().replace(" ", "_")
		if SettingsManager.get_top_bar_menu_position(key) == 1:
			continue
		menu.add_item(menu_buttons[id].title, id)
		menu.set_item_icon(id, menu_buttons[id].icon)
		menu.set_item_tooltip(id, menu_buttons[id].tooltip)
		if menu_buttons[id].title == "Project settings":
			%TopEditorButton.get_popup().set_item_disabled(id, true)
			ProjectManager._on_project_loaded.connect(func(): 
				%TopEditorButton.get_popup().set_item_disabled(id, false))


func _on_project_button_pressed() -> void:
	ScreenMain.instance.show_screen(ScreenMain.SCREENS.PROJECT_SETTINGS)


func _on_settings_button_pressed() -> void:
	ScreenMain.instance.show_screen(ScreenMain.SCREENS.SETTINGS)

#endregion
###############################################################
