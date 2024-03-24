extends HBoxContainer
# TODO: Add links from start menu to TopEditorButton


func _ready() -> void:
	var menu: PopupMenu = get_node("TopEditorButton").get_popup()
	menu.id_pressed.connect(_on_popup_menu_id_pressed)
	menu.mouse_exited.connect(_on_top_editor_popup_menu_mouse_exited.bind(menu))


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


func _on_settings_button_pressed():
	PopupManager.open_popup(PopupManager.POPUP.SETTINGS_MENU)


func _on_project_settings_button_pressed():
	PopupManager.open_popup(PopupManager.POPUP.PROJECT_SETTINGS_MENU)


func _on_popup_menu_id_pressed(id: int) -> void:
	match id:
		0: # Report bug
			PopupManager.open_popup(PopupManager.POPUP.BUG_REPORT)
		2: # Manuals
			OS.shell_open(Globals.URL_MANUAL)
		3: # Tutorials
			OS.shell_open(Globals.URL_TUTORIALS)
		4: # Github
			OS.shell_open(Globals.URL_GITHUB_REPO)
		5: # Discord
			OS.shell_open(Globals.URL_DISCORD)
		6: # Support this project
			OS.shell_open(Globals.URL_SUPPORT_PROJECT)


func _on_top_editor_popup_menu_mouse_exited(menu: PopupMenu) -> void:
	menu.visible = false
