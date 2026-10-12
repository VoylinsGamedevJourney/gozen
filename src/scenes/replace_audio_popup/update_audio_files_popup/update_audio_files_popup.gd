extends Control


signal confirm_clips
signal confirm_file


@export var label: Label



func set_data(clip_amount: int) -> void:
	label.text = label.text % clip_amount


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel", false, true):
		_on_close_button_pressed()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			_on_close_button_pressed()


func _on_apply_to_all_button_pressed() -> void:
	confirm_clips.emit()


func _on_apply_to_file_button_pressed() -> void:
	confirm_file.emit()


func _on_close_button_pressed() -> void:
	PopupManager.close(PopupManager.SAVE_PROFILE_PRESET)
