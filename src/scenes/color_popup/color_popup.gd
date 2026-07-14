extends Control

@export var color_picker: ColorPicker


func _on_create_color_pressed() -> void:
	FileLogic.add(["temp://color#" + color_picker.color.to_html()])
	PopupManager.close(PopupManager.COLOR)


func _input(event: InputEvent) -> void:
	# Needed as focus could be in line edit.
	if event.is_action_pressed("ui_cancel"):
		_on_cancel_button_pressed()
		get_viewport().set_input_as_handled()


func _on_cancel_button_pressed() -> void:
	PopupManager.close(PopupManager.COLOR)
