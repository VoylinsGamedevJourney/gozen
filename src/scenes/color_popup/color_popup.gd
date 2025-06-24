extends PanelContainer


@export var color_picker: ColorPicker



func _on_create_color_pressed() -> void:
	var file: File = File.create("temp://color")
	var color: Color = color_picker.color

	file.nickname = "Color #" + color.to_html(true)
	file.temp_file = TempFile.new()
	file.temp_file.color = color
	file.temp_file.load_image()

	Project.add_file_object(file)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()

