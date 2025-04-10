extends PanelContainer


@export var background_color_picker: ColorPickerButton


var changes: Dictionary[String, Callable] = {}



func _ready() -> void:
	set_values()


func set_values() -> void:
	background_color_picker.color = Project.get_background_color()


func _on_save_button_pressed() -> void:
	for change: Callable in changes.values():
		change.call()

	Project.save()
	self.queue_free()


func _on_cancel_button_pressed() -> void:
	self.queue_free()


func _on_background_color_picker_button_color_changed(color: Color) -> void:
	changes["background_color"] = Project.set_background_color.bind(color)

