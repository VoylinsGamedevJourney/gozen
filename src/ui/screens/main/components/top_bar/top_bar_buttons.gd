extends HBoxContainer

@onready var top_editor_menu: MenuButton = self.get_node("TopEditorButton")
@onready var top_menu_hbox: HBoxContainer = self.get_node("TopMenuButtons")


var menu_buttons := []


func _ready():
	# TODO: Fetch all custom module buttons
	set_default_menu_buttons()
	set_button_positions()
	
	top_menu_hbox.get_node("ProjectSettingsButton").visible = false
	ProjectManager._on_project_loaded.connect(func() -> void: 
		top_menu_hbox.get_node("ProjectSettingsButton").visible = true)


###############################################################
#region Top Bar Window Buttons  ###############################
###############################################################

func _on_minimize_button_pressed() -> void:
	TopBar.instance.win_mode = Window.MODE_MINIMIZED


func _on_switch_mode_button_pressed() -> void:
	if TopBar.instance.win_mode == Window.MODE_WINDOWED:
		TopBar.instance.win_mode = Window.MODE_MAXIMIZED
	else:
		TopBar.instance.win_mode = Window.MODE_WINDOWED


func _on_exit_button_pressed() -> void:
	if ProjectManager.project_path == "":
		get_tree().quit()
		return
	var dialog := ConfirmationDialog.new()
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
###############################################################
#region Top Bar Buttons  ######################################
###############################################################

func set_default_menu_buttons() -> void:
	top_editor_menu.get_popup().id_pressed.connect(func(id: int) -> void:
		menu_buttons[id].function.call())
	SettingsManager._on_top_bar_positions_changed.connect(set_button_positions)
	add_menu_button( # Project settings
		"res://assets/icons/movie_edit.png",
		"Project settings",
		func() -> void: ScreenMain.instance.open_project_settings_popup(),
		"BUTTONS_PROJECT_SETTINGS_TOOLTIP")
	add_menu_button( # Settings
		"res://assets/icons/settings_video_camera.png",
		"Settings",
		func() -> void: ScreenMain.instance.open_settings_popup(),
		"BUTTONS_SETTINGS_TOOLTIP")
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
	top_menu_hbox.add_child(button)


func add_separator(title: String) -> void:
	menu_buttons.append(title)


func set_button_positions() -> void:
	var menu: PopupMenu = top_editor_menu.get_popup()
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
			top_editor_menu.get_popup().set_item_disabled(id, true)
			ProjectManager._on_project_loaded.connect(func() -> void: 
				top_editor_menu.get_popup().set_item_disabled(id, false))

#endregion
###############################################################
