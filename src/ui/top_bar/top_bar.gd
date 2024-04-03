extends HBoxContainer


func _on_settings_button_pressed() -> void:
	PopupManager.open_popup(PopupManager.POPUP.SETTINGS_MENU)


func _on_project_settings_button_pressed() -> void:
	PopupManager.open_popup(PopupManager.POPUP.PROJECT_SETTINGS_MENU)


func _on_minimize_button_pressed() -> void:
	WindowHandler.win_mode = Window.MODE_MINIMIZED


func _on_maximize_button_pressed() -> void:
	if WindowHandler.win_mode == Window.MODE_WINDOWED:
		WindowHandler.win_mode = Window.MODE_MAXIMIZED
	else:
		WindowHandler.win_mode = Window.MODE_WINDOWED


func _on_exit_button_pressed() -> void:
	WindowHandler._on_exit_request()


func _on_top_bar_dragging(a_event: InputEvent) -> void:
	WindowHandler._on_top_bar_dragging(a_event)
