class_name DataManager
extends Node



static func get_data(instance: Node) -> Dictionary[String, Variant]:
	var data: Dictionary[String, Variant] = {}

	for property: Dictionary in instance.get_property_list():
		if property.name[0] != '_' and property.usage in [4096, 4102, 69632]:
			data[property.name] = instance.get(str(property.name))

	return data


static func save_data(save_path: String, instance: Node) -> int:
	var error: int = OK
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)

	if FileAccess.get_open_error():
		error = ERR_FILE_CANT_OPEN
		return error

	var data: Dictionary[String, Variant] = get_data(instance)

	if !file.store_string(var_to_str(data)):
		printerr("Something went wrong storing data to file: ", save_path)

	error = file.get_error()
	return error


static func load_data(a_path: String, instance: Node) -> int:
	var error: int = OK
	var file: FileAccess
	var data: Dictionary

	if !FileAccess.file_exists(a_path):
		error = ERR_FILE_NOT_FOUND
		return error

	file = FileAccess.open(a_path, FileAccess.READ)
	if FileAccess.get_open_error():
		error = ERR_FILE_CANT_OPEN
		return error

	data = str_to_var(file.get_as_text())
	for key: String in data.keys():
		instance.set(key, data[key])

	error = file.get_error()
	return error

