extends Control


signal confirmed(new_frame: float)


@export var spinbox: SpinBox



## This is basically our _ready() for the popup.
func set_data(frame: int, max_frame: int) -> void:
	spinbox.max_value = max_frame
	spinbox.value = frame
	spinbox.grab_focus()
	spinbox.get_line_edit().text_submitted.connect(_on_apply_button_pressed.unbind(1))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel", false, true):
		_on_close_button_pressed()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			_on_close_button_pressed()


func _on_apply_button_pressed() -> void:
	EditorCore.set_frame(spinbox.value as int)


func _on_close_button_pressed() -> void:
	PopupManager.close(PopupManager.JUMP_TO_FRAME)
