extends PanelContainer

@export var rename_line_edit: LineEdit


var file: FileData = null



func set_data(file_data: FileData) -> void:
	file = file_data
	rename_line_edit.text = file.nickname
	rename_line_edit.grab_focus()


func _input(event: InputEvent) -> void:
	# Needed as focus could be in line edit.
	if event.is_action_pressed("ui_cancel"):
		_on_cancel_button_pressed()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			_on_cancel_button_pressed()


func _on_save_button_pressed() -> void:
	_on_rename_file_line_edit_text_submitted(rename_line_edit.text)


func _on_rename_file_line_edit_text_submitted(new_nickname: String) -> void:
	# Only save if an actual new nickname got given.
	if new_nickname != "" and file.nickname != new_nickname:
		FileLogic.set_nickname(file, new_nickname)
	_on_cancel_button_pressed()


func _on_cancel_button_pressed() -> void:
	PopupManager.close(PopupManager.FILE_RENAME)
