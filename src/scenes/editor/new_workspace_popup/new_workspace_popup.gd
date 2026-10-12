extends Control


signal confirmed(workspace_name: String)


@export var label: Label



func set_data(workspace_name: String) -> void:
	label.text = label.text % workspace_name


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel", false, true):
		_on_close_button_pressed()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			_on_close_button_pressed()


func _on_save_workspace_button_pressed() -> void:
	confirmed.emit(line_edit_workspace_name.text)


func _on_close_button_pressed() -> void:
	PopupManager.close(PopupManager.SAVE_PROFILE_PRESET)
