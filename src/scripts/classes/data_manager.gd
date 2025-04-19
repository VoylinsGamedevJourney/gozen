class_name DataManager
extends Node


var error: int = OK



func save_data(save_path: String) -> int:
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if FileAccess.get_open_error():
		error = ERR_FILE_CANT_OPEN
		return error

	var data: Dictionary = {}
	for property: Dictionary in get_property_list():
		if property.usage in [4096, 4102, 69632]:
			data[property.name] = get(str(property.name))

	if !file.store_string(var_to_str(data)):
		printerr("Something went wrong storing data to file: ", save_path)

	error = file.get_error()
	return error


func load_data(a_path: String) -> int:
	if !FileAccess.file_exists(a_path):
		error = ERR_FILE_NOT_FOUND
		return error

	var file: FileAccess = FileAccess.open(a_path, FileAccess.READ)
	if FileAccess.get_open_error():
		error = ERR_FILE_CANT_OPEN
		return error

	var data: Dictionary = str_to_var(file.get_as_text())
	for key: String in data.keys():
		set(key, data[key])

	error = file.get_error()
	return error

