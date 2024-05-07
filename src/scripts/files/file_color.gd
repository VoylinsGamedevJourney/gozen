class_name FileColor extends File


var color: Color


func _init() -> void:
	type = FILE_COLOR
	duration = SettingsManager.get_default_color_duration()


static func create(a_color: Color) -> FileColor:
	var l_file: FileColor = FileColor.new()
	l_file.color = a_color
	return l_file
