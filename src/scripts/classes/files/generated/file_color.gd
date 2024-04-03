class_name FileColor extends File
# TODO: Way for saving color shortcuts to use in multiple projects

var color: Color
var size: int


func _init() -> void:
	type = TYPE.COLOR
	duration = 120 # TODO: Make possible to change default
