extends Node

@onready var main_node := get_node("/root/Main")

signal file_explorer_passthrough(path)


func open_window(window_name: String, close_others: bool = true) -> void:
	if close_others: close_windows()
	
	var new_window := load("res://windows/%s.tscn" % window_name)
	main_node.add_child(new_window.instantiate())


func close_window(window_name: String) -> void:
	var window_path := '/root/Main/%s' % window_name
	if get_node(window_path) == null:
		printerr("No window with name '%s' was found!" % window_name)
	get_node(window_path).queue_free()


func close_windows():
	for window in main_node.get_children():
		window.queue_free()
