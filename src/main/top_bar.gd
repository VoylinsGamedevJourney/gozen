extends HBoxContainer

@onready var label_window_title: Label = $TopBarPanel/WindowTitleLabel


func _ready() -> void:
	label_window_title.text = tr("TEXT_UNTITLED_PROJECT_TITLE")
	ProjectManager._on_title_changed.connect(_on_project_title_changed)
	ProjectManager._on_unsaved_changes_changed.connect(_on_project_unsaved_changes_changed)


func _on_project_title_changed(a_title: String) -> void:
	# Extra space is needed for the '*' mark to indicate unsaved changes
	label_window_title.text = a_title + " "


func _on_project_unsaved_changes_changed(a_value: bool) -> void:
	label_window_title.text[-1] = "*" if a_value else " "


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
