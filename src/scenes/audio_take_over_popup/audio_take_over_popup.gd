extends Control
# TODO: When this is done for a file with existing clips attached, we should
# show a different popup which asks if we want to update the existing clips too.

var current_file_id: int = -1
var current_clip_id: int = -1



func load_data(id: int, is_file: bool) -> void:
	if is_file: current_file_id = id
	else: current_clip_id = id
