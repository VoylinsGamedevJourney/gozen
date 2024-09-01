extends DataManager


signal _on_project_saved
signal _on_project_loaded



var _project_path: String = ""



func save() -> void:
	if _project_path == "":
		printerr("Project path is empty, can't save!")
	elif save_data(_project_path) == ERR_FILE_CANT_OPEN:
		printerr("Couldn't open settings file for saving! ", _project_path)
	else:
		_on_project_saved.emit()


func load(a_path: String) -> void:
	if load_data(a_path) == ERR_FILE_CANT_OPEN:
		printerr("Couldn't open settings file for loading! ", a_path)
	else:
		_on_project_loaded.emit()

