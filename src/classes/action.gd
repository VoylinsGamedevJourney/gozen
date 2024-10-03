class_name Action
extends Node


var function: Callable
var undo_function: Callable
var do_args: Array = []
var undo_args: Array = []


func _init(a_func: Callable, a_undo_func: Callable, a_do_args: Array, a_undo_args: Array) -> void:
	function = a_func
	undo_function = a_undo_func
	do_args = a_do_args
	undo_args = a_undo_args
