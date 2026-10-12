extends Control


@export var label_count: Label
@export var label_zero: Label



## This is basically our _ready() for the popup.
func set_data(added_count: int) -> void:
	if added_count > 0:
		label_count.text = label_count.text % added_count
		label_zero.visible = false
	else:
		label_count.visible = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel", false, true):
		_on_close_button_pressed()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			_on_close_button_pressed()


func _on_close_button_pressed() -> void:
	PopupManager.close(PopupManager.SCAN_COMPLETE)
