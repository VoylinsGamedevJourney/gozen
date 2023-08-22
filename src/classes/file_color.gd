class_name FileColor extends File

var color_name: String
var color: Color


static func create(color: Color, duration: int) -> FileColor:
	var file_color := FileColor.new()
	file_color.type = TYPE.COLOR
	file_color.color = color
	file_color.duration = duration
	return file_color
