class_name StartupModule extends Node
## The Startup Module Interface
##
## Still WIP


func get_project_title(project_path: String) -> String:
	if !FileAccess.file_exists(project_path): return ""
	var project_file := FileAccess.open_compressed(project_path,FileAccess.READ)
	var data: Dictionary = project_file.get_var()
	return data.title


func close_startup() -> void:
	self.queue_free()
