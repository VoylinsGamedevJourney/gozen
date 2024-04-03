extends Window


func _ready() -> void:
	set_current_values()


func _input(a_event: InputEvent) -> void:
	if a_event.is_action_pressed("ui_cancel"):
		_on_close_requested()


func set_current_values() -> void:
	# General settings
	%ProjectTitleLineEdit.text = ProjectManager.title
	
	# Quality settings
	%ResolutionXSpinBox.value = ProjectManager.resolution.x
	%ResolutionYSpinBox.value = ProjectManager.resolution.y
	%FramerateSpinBox.value = ProjectManager.framerate


func _on_close_requested() -> void:
	PopupManager.close_popup(PopupManager.POPUP.PROJECT_SETTINGS_MENU)


#region  ####################  Getters & Setters  ##############################

func _on_project_title_line_edit_text_submitted(a_title) -> void:
	ProjectManager.title = a_title


func _on_framerate_spin_box_value_changed(a_value) -> void:
	ProjectManager.framerate = a_value


func _on_resolution_x_spin_box_value_changed(a_value) -> void:
	ProjectManager.resolution.x = a_value


func _on_resolution_y_spin_box_value_changed(a_value) -> void:
	ProjectManager.resolution.y = a_value

#endregion
