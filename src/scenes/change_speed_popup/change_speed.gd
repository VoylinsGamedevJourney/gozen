extends Control


signal confirmed(new_speed: float)


@export var spinbox_speed: SpinBox



## This is basically our _ready() for the popup.
func set_data(speed: float) -> void:
	spinbox_speed.value = speed
	spinbox_speed.grab_focus()
	spinbox_speed.get_line_edit().text_submitted.connect(_on_enter_pressed.unbind(1))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel", false, true):
		_on_close_button_pressed()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			_on_close_button_pressed()

func _on_enter_pressed() -> void:
	# Call deferred, so the spinbox has time to read the value
	# of the just submitted text
	_on_apply_button_pressed.call_deferred()

func _on_apply_button_pressed() -> void:
	confirmed.emit(spinbox_speed.value)
	_on_close_button_pressed()


func _on_close_button_pressed() -> void:
	PopupManager.close(PopupManager.CHANGE_CLIP_SPEED)
