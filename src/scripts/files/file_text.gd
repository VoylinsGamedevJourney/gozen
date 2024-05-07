class_name FileText extends File


var text: String = ""
var font_size: int = 1
var font: String = ""
var pos: Vector2i = Vector2i.ZERO


func _init() -> void:
	type = FILE_TEXT
	duration = SettingsManager.get_default_text_duration()


static func create(a_text: String, a_font_size: int, a_font: String, a_pos: Vector2i) -> FileText:
	var l_file: FileText = FileText.new()
	l_file.text = a_text
	l_file.font_size = a_font_size
	l_file.font = a_font
	l_file.pos = a_pos
	return l_file
