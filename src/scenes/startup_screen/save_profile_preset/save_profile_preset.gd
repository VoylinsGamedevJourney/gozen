extends Control


signal confirmed(preset_name: String)


@export var line_edit_preset_name: LineEdit


var project_profile: ProjectProfile



func set_data(profile: ProjectProfile) -> void:
	project_profile = profile
	line_edit_preset_name.grab_focus()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel", false, true):
		_on_close_button_pressed()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			_on_close_button_pressed()


func _on_save_preset_button_pressed() -> void:
	var user_profiles_path: String = Utils.get_config_dir().path_join("profiles/project")
	var preset_name: String = line_edit_preset_name.text.strip_edges()
	if preset_name.is_empty():
		preset_name = "Custom"

	project_profile.profile_name = preset_name

	if not DirAccess.dir_exists_absolute(user_profiles_path):
		var _dir_err: int = DirAccess.make_dir_recursive_absolute(user_profiles_path)

	var save_path: String = user_profiles_path.path_join(preset_name.validate_filename() + ".tres")
	ResourceSaver.save(project_profile, save_path)
	confirmed.emit(preset_name)

	_on_close_button_pressed()


func _on_close_button_pressed() -> void:
	PopupManager.close(PopupManager.SAVE_PROFILE_PRESET)
