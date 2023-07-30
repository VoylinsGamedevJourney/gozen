extends Node

var error: int


func save_dic(dic: Dictionary, file_path: String, compress: bool = false) -> void:
	var file : FileAccess
	if compress:
		file = FileAccess.open_compressed(file_path, FileAccess.WRITE)
	else:
		file = FileAccess.open(file_path, FileAccess.WRITE)
	error = FileAccess.get_open_error()
	if error:
		printerr("Could not open file '%s' for saving!\n\tError: %s" % [file_path, error])
		return
	file.store_var(dic)
	error = file.get_error()
	if error:
		printerr("Could not save data to '%s'!\n\tError: %s" % [file_path, error])
	file.close()


func load_dic(file_path: String, compress: bool = false) -> Dictionary:
	var file : FileAccess
	if compress:
		file = FileAccess.open_compressed(file_path, FileAccess.READ)
	else:
		file = FileAccess.open(file_path, FileAccess.READ)
	error = FileAccess.get_open_error()
	if error:
		printerr("Could not open file '%s' for loading dic!\n\tError: %s" % [file_path, error])
		return {}
	var dic: Dictionary = file.get_var()
	error = file.get_error()
	if error:
		printerr("Could not load dic to '%s'!\n\tError: %s" % [file_path, error])
	file.close()
	return dic
