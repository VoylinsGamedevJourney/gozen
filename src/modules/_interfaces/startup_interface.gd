class_name StartupModule extends Node


#func get_recent_projects_list() -> Array:
#	if !FileAccess.file_exists(PATH_RECENT_PROJECTS): return []
#	var file := FileAccess.open(PATH_RECENT_PROJECTS, FileAccess.READ)
#	var data: Array = file.get_var()
#	var list: Array
#	for entry in data:
#		if FileAccess.file_exists(entry): list.append(entry)
#	return list


#func push_entry_to_front(entry: String, list: Array, new: bool = false) -> Array:
#	if !new: list.remove_at(list.find(entry))
#	var new_list := [entry]
#	new_list.append_array(list)
#	return new_list
#
#
#func save_recent_projects_list(list: Array) -> void:
#	pass


func get_project_title(project_path: String) -> String:
	if !FileAccess.file_exists(project_path): return ""
	var project_file := FileAccess.open_compressed(project_path,FileAccess.READ)
	var data: Dictionary = project_file.get_var()
	return data.title


func close_startup() -> void:
	Globals._on_exit_startup.emit()
	self.queue_free()
