extends TopBarModule

# TODO: Have an option to switch the order of these buttons from right to left
# TODO: Make this top_bar invisible in zen mode


func _ready() -> void:
	Globals._on_project_title_change.connect(on_project_title_change)
	Globals._on_project_saved.connect(on_project_saved)
	Globals._on_project_unsaved_changes.connect(on_project_unsaved_changes)


func on_project_title_change() -> void:
	$ProjectTitleLabel.text = ProjectManager.title


func on_project_saved() -> void:
	if $ProjectTitleLabel.text[-1] == '*':
		$ProjectTitleLabel.text = $ProjectTitleLabel.text.trim_suffix('*')


func on_project_unsaved_changes() -> void:
	if $ProjectTitleLabel.text[-1] != '*':
		$ProjectTitleLabel.text += '*'


func _on_project_button_pressed() -> void:
	Globals._on_open_project_settings.emit()


func _on_settings_button_pressed() -> void:
	Globals._on_open_settings.emit()


func _on_minimize_button_pressed() -> void:
	get_window().set_mode(Window.MODE_MINIMIZED)


func _on_switch_mode_button_pressed() -> void:
	match get_window().mode:
		Window.MODE_WINDOWED:  get_window().set_mode(Window.MODE_MAXIMIZED)
		Window.MODE_MAXIMIZED: get_window().set_mode(Window.MODE_WINDOWED)


func _on_exit_button_pressed() -> void:
	# TODO: Check if unsaved changes and first display a message
	#       asking if they want to save or not
	get_tree().quit()
