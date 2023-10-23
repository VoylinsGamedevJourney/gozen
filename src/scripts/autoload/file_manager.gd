extends Node

const OPEN_ERROR := "Could not open file '%s' for %s!\n\tError: %s"
const PROCESS_ERROR := "Could not %s data to '%s'!\n\tError: %s"



func save_data(data, path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	var error := FileAccess.get_open_error()
	if error:
		printerr(OPEN_ERROR % [path, "saving", error])
		return false
	file.store_string(var_to_str(data))
	error = file.get_error()
	if error:
		printerr(PROCESS_ERROR % ["save", path, error])
		return false
	return true


func load_data(path: String) -> String:
	if !FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	var error := FileAccess.get_open_error()
	if error:
		printerr(OPEN_ERROR % [path, "loading", error])
		return ""
	var string := file.get_as_text()
	error = file.get_error()
	if error:
		printerr(PROCESS_ERROR % ["load", path, error])
		return ""
	return string
