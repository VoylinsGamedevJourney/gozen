class_name DataManager
extends Node


func save_data(a_path: String) -> int:
	var l_file: FileAccess = FileAccess.open(a_path, FileAccess.WRITE)
	var l_data: Dictionary = {}

	if FileAccess.get_open_error():
		return ERR_FILE_CANT_OPEN

	for l_property: Dictionary in get_property_list():
		match [l_property.name, l_property.usage]:
			[var l_name, _]  when l_name[0] == '_': continue
			[_, var l_usage] when l_usage & PROPERTY_USAGE_EDITOR:     continue
			[_, var l_usage] when l_usage == PROPERTY_USAGE_NO_EDITOR: continue
			[var l_name, var l_usage] when l_usage & 4096 or l_usage & 4102:
				l_data[l_name] = get(str(l_name))

	if !l_file.store_string(var_to_str(l_data)):
		printerr("Something went wrong storing data to file: ", a_path)

	return l_file.get_error() if l_file.get_error() != 0 else OK


func load_data(a_path: String) -> int:
	if FileAccess.file_exists(a_path):
		var l_file: FileAccess = FileAccess.open(a_path, FileAccess.READ)

		if FileAccess.get_open_error():
			return ERR_FILE_CANT_OPEN

		var l_data: Dictionary = str_to_var(l_file.get_as_text())

		for l_key: String in l_data.keys():
			set(l_key, l_data[l_key])

		return l_file.get_error() if l_file.get_error() != 0 else OK
	return ERR_FILE_NOT_FOUND
