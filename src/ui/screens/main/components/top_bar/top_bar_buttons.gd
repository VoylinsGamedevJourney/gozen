extends HBoxContainer
# TODO: Add links from start menu to TopEditorButton


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
	var popup_name := "settings_popup"
	if has_node(popup_name):
		get_node(popup_name).visible = true
		return
	var popup: Window = preload(
		"res://ui/popups/settings_menu/settings_menu.tscn").instantiate()
	popup.name = popup_name
	add_child(popup)


func _on_project_settings_button_pressed():
	var popup_name := "project_settings_popup"
	if has_node(popup_name):
		get_node(popup_name).visible = true
		return
	var popup: Window = preload(
		"res://ui/popups/project_settings_menu/project_settings_menu.tscn").instantiate()
	popup.name = popup_name
	add_child(popup)
