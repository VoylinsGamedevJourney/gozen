class_name Loadable
extends Node


var info_text: String
var function: Callable
var delay: float


func _init(a_info_text: String, a_func: Callable, a_delay: float = 0) -> void:
	info_text = a_info_text
	function = a_func
	delay = a_delay

