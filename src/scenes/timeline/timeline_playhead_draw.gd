extends Control

@export var draw_function_name: String = ""



func _draw() -> void:
	get_parent().call(draw_function_name, self)
