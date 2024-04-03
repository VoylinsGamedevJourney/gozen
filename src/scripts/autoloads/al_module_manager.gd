extends Node ## Module manager


enum TYPE { LAYOUT, MODULE, EFFECT, TRANSITION,  }


func _ready() -> void:
	## Creating necessary structures and loading/checking all custom modules
	_load_modules(TYPE.LAYOUT)
	_load_modules(TYPE.MODULE)
	_load_modules(TYPE.EFFECT)
	_load_modules(TYPE.TRANSITION)


func _load_modules(a_type: TYPE) -> void:
	var l_path: String = get_custom_modules_folder(a_type)
	
	# Creating necesarry folders if not existing already
	DirAccess.make_dir_recursive_absolute(l_path)
	DirAccess.make_dir_recursive_absolute(get_config_folder(a_type))
	
	# Loading in all custom module files of 'type'
	if DirAccess.get_files_at(l_path).size() != 0:
		for l_file: String in DirAccess.get_files_at(l_path):
			if Toolbox.check_extension(l_file, ["pck"]):
				ProjectSettings.load_resource_pack(l_path + l_file, false)


func get_type_string(a_type: TYPE) -> String:
	match a_type:
		TYPE.LAYOUT: return "layouts"
		TYPE.MODULE: return "modules"
		TYPE.EFFECT: return "effects"
		TYPE.TRANSITION: return "transitions"
		_: return ""


func get_custom_modules_folder(a_type: TYPE) -> String:
	return "user://modules/%s/" % get_type_string(a_type)


func get_config_folder(a_type: TYPE) -> String:
	return "user://module_configs/%s/" % get_type_string(a_type)


func get_config_file(a_type: TYPE, a_file_name: String) -> String:
	return get_config_folder(a_type) + a_file_name


func get_module_info(a_type: TYPE, a_module_name: String) -> Module:
	return load("res://_%s/%s/info.tres" % [get_type_string(a_type), a_module_name])


func get_layout_info(a_layout_name: String) -> LayoutModule:
	return load("res://_%s/layout_%s/info.tres" % [get_type_string(TYPE.LAYOUT), a_layout_name])


func create_module_id(a_type: TYPE, a_module_name: String) -> String:
	var l_new_name: String = "%s-%s" % [a_module_name, randi_range(100000, 999999)]
	while l_new_name in DirAccess.get_files_at(get_config_folder(a_type)):
		randomize()
		l_new_name = "%s-%s" % [a_module_name, randi_range(100000, 999999)]
	return l_new_name


func remove_config_layout(a_instance_name: String) -> void:
	DirAccess.remove_absolute("%s%s.cfg" % [get_config_folder(TYPE.LAYOUT), a_instance_name])
