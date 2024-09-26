class_name Loadable
extends Node


var info_text: String
var function: Callable


func _init(a_info_text: String, a_func: Callable) -> void:
	info_text = a_info_text
	function = a_func

