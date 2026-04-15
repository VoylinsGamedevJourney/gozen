class_name DataManager
extends RefCounted



static func get_data(instance: RefCounted) -> Dictionary[String, Variant]:
	if instance.has_method("serialize"):
		@warning_ignore("unsafe_method_access")
		return instance.serialize()

	var data: Dictionary[String, Variant] = {}
	for property: Dictionary in instance.get_property_list():
		if property.name[0] != '_' and property.usage in [4096, 4102, 69632]:
			data[property.name] = instance.get(str(property.name))
	return data


static func save_data(save_path: String, instance: RefCounted) -> int:
	var tmp_path: String = save_path + ".tmp"
	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if FileAccess.get_open_error():
		printerr("DataManager: Something went wrong opening file '%s'!" % tmp_path)
		return ERR_FILE_CANT_OPEN

	var data: Dictionary[String, Variant] = get_data(instance)
	if !file.store_string(var_to_str(data)):
		printerr("DataManager: Something went wrong storing data to file '%s'!" % tmp_path)
		return file.get_error()

	var dir: DirAccess = DirAccess.open(save_path.get_base_dir())
	var file_name: String = save_path.get_file()
	var tmp_name: String = file_name + ".tmp"
	if dir.file_exists(file_name):
		if !dir.remove(file_name):
			printerr("DataManager: Problem happened on removing '%s'!" % file_name)
	if !dir.rename(tmp_name, file_name):
		printerr("DataManager: Problem happened on renaming '%s' to '%s'!" % [tmp_name, file_name])
	return OK


static func load_data(a_path: String, instance: RefCounted) -> int:
	var file: FileAccess
	var data: Dictionary
	if !FileAccess.file_exists(a_path):
		return ERR_FILE_NOT_FOUND

	file = FileAccess.open(a_path, FileAccess.READ)
	if FileAccess.get_open_error():
		return ERR_FILE_CANT_OPEN

	data = str_to_var(file.get_as_text())
	if instance.has_method("deserialize"):
		@warning_ignore("unsafe_method_access")
		instance.deserialize(data)
		return OK

	for key: String in data.keys():
		instance.set(key, data[key])
	return OK
