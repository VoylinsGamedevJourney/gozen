class_name FileColor

var color_name: String
var color: Color
var duration: int # Duration in frames


static func create(color: Color, duration: int) -> FileColor:
	var file_color := FileColor.new()
	file_color.color = color
	file_color.duration = duration
	return file_color
