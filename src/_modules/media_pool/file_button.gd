extends Button



func _get_drag_data(_at_position: Vector2) -> Dictionary:
	var l_file: File = ProjectManager.files_data[get_meta("file_id")]
	return {
		"file_id": get_meta("file_id"),
		"file_type": l_file.type,
		"duration": l_file.duration
	}


func _can_drop_data(_at_position: Vector2, _data: Variant) -> bool:
	return false

