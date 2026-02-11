extends PanelContainer

@export var color_picker: ColorPicker


func _on_create_color_pressed() -> void:
	Project.files.add(["temp://color#" + color_picker.color.to_html()])
	queue_free()


func _on_cancel_button_pressed() -> void: queue_free()
