class_name FileColor extends File

var color_name: String
var color: Color


func _init(file_color: Color, file_duration: int = 7*30) -> void:
	type = TYPE.COLOR
	color = file_color
	duration = file_duration
