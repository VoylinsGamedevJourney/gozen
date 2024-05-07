class_name DataHandler extends Node


func save_data(a_path: String) -> void:
	var l_file: FileAccess = FileAccess.open(a_path, FileAccess.WRITE)
	var l_data: Dictionary = {}
	for l_dic: Dictionary in get_property_list():
		if (l_dic.usage == 4096 or l_dic.usage == 4102) and l_dic.name[0] != "_":
			l_data[l_dic.name] = get(l_dic.name)
	l_file.store_string(var_to_str(l_data))


func load_data(a_path: String) -> void:
	if FileAccess.file_exists(a_path):
		var l_file: FileAccess = FileAccess.open(a_path, FileAccess.READ)
		var l_data: Dictionary = str_to_var(l_file.get_as_text())
		for l_key: String in l_data.keys():
			set(l_key, l_data[l_key])
