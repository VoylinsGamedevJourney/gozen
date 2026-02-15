extends Control

@export var draw_func_name: String = ""



func _draw() -> void:
	get_parent().call(draw_func_name, self)
