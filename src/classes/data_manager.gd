class_name DataManager
extends Node


func _save_data(a_path: String) -> int:
	OS.set_use_file_access_save_and_swap(true)
	var l_file: FileAccess = FileAccess.open(a_path, FileAccess.WRITE)
	if FileAccess.get_open_error():
		OS.set_use_file_access_save_and_swap(false)
		return ERR_FILE_CANT_OPEN

	var l_data: Dictionary = {}
	for l_property: Dictionary in get_property_list():
		var l_usage: int = l_property.usage
		var l_name: String = l_property.name
		if ((l_usage == 4096 || l_usage == 4102) && l_name[0] != '_'):
			l_data[l_name] = get(l_name)

	l_file.store_string(var_to_str(l_data))
	if l_file.get_error() != 0:
		OS.set_use_file_access_save_and_swap(false)
		return l_file.get_error()

	l_file.close()
	OS.set_use_file_access_save_and_swap(false)
	return OK


func _load_data(a_path: String) -> int:
	if (FileAccess.file_exists(a_path)):
		var l_file: FileAccess = FileAccess.open(a_path, FileAccess.READ)
		if FileAccess.get_open_error():
			OS.set_use_file_access_save_and_swap(false)
			return ERR_FILE_CANT_OPEN

		var l_data: Dictionary = str_to_var(l_file.get_as_text())
		for l_key: String in l_data.keys():
			set(l_key, l_data[l_key])

		if l_file.get_error() != 0:
			OS.set_use_file_access_save_and_swap(false)
			return l_file.get_error()

		l_file.close()
		OS.set_use_file_access_save_and_swap(false)
		return OK

	OS.set_use_file_access_save_and_swap(false)
	return ERR_FILE_NOT_FOUND


func _save_data_err(a_path: String, a_string: String) -> void:
	# For when you don't want/need to handle the error value and just print
	var l_err: int = _save_data(a_path)
	if l_err:
		printerr(a_string, " Error: ", l_err, " Path: ", a_path)


func _load_data_err(a_path: String, a_string: String) -> void:
	# For when you don't want/need to handle the error value and just print
	var l_err: int = _load_data(a_path)
	if l_err:
		printerr(a_string, " Error: ", l_err, " Path: ", a_path)

