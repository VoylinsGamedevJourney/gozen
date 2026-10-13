extends Control


signal confirmed(folder_name: String)


@export var line_edit: LineEdit



## This is basically our _ready() for the popup.
func set_data() -> void:
	line_edit.grab_focus()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel", false, true):
		_on_close_button_pressed()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			_on_close_button_pressed()


func _on_line_edit_text_submitted(_new_text: String) -> void:
	_on_create_button_pressed()


func _on_create_button_pressed() -> void:
	confirmed.emit(line_edit.text)


func _on_close_button_pressed() -> void:
	PopupManager.close(PopupManager.CREATE_FOLDER)
