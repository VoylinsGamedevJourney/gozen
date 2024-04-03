class_name FileText extends File
# TODO: Option for saving text styles to use in multiple projects

var text: String
var font_size: int
var font: String
var pos: Vector2i # position


func _init() -> void:
	type = TYPE.TEXT
	duration = 120 # TODO: Make possible to change default
