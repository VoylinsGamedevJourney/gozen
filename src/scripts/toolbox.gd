class_name Toolbox extends Node


static func beautify_name(a_string: String) -> String:
	return a_string.replace('_', ' ').capitalize()


static func check_extension(a_path: String, a_extensions: PackedStringArray) -> bool:
	return a_path.split('.')[-1].strip_edges().to_lower() in a_extensions


static func get_icon_tex2d(a_icon_name: String) -> Texture2D:
	return load("res://assets/icons/%s.png" % a_icon_name)


static func os_is_windows() -> bool:
	return OS.get_name() == "Windows"


static func free_node(a_node: Node) -> void:
	a_node.queue_free()


static func file_exists(a_path: String, a_error: String) -> bool:
	if FileAccess.file_exists(a_path):
		return true
	else:
		Printer.error(a_error % a_path)
		return false
