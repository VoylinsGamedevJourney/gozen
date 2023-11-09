extends ModuleProjectSettingsMenu

# TODO: Make the settings menu build itself with provided data

var startup := true


func _ready() -> void:
	%TitleLineEdit.text = ProjectManager.get_title()
	%ResolutionXSpinBox.value = ProjectManager.get_resolution().x
	%ResolutionYSpinBox.value = ProjectManager.get_resolution().y
	%FramerateSpinBox.value = ProjectManager.get_framerate()
	startup = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		queue_free()


func _on_title_line_edit_text_changed(new_title: String) -> void:
	ProjectManager.set_title(new_title)


func _on_resolution_x_spin_box_value_changed(new_x: float) -> void:
	if startup:
		return
	var resolution := ProjectManager.get_resolution()
	resolution.x = int(new_x)
	ProjectManager.set_resolution(resolution)


func _on_resolution_y_spin_box_value_changed(new_y: float) -> void:
	if startup:
		return
	var resolution := ProjectManager.get_resolution()
	resolution.y = int(new_y)
	ProjectManager.set_resolution(resolution)


func _on_framerate_spin_box_value_changed(value: float) -> void:
	if startup:
		return
	ProjectManager.set_framerate(value)
