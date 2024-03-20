extends Node ## Module manager


enum TYPE { LAYOUT, MODULE, EFFECT, TRANSITION, RENDER_PROFILE }


func _ready() -> void:
	## Creating necessary structures and loading/checking all custom modules
	_load_modules(TYPE.LAYOUT)
	_load_modules(TYPE.MODULE)
	_load_modules(TYPE.EFFECT)
	_load_modules(TYPE.TRANSITION)
	_load_modules(TYPE.RENDER_PROFILE)


func _load_modules(type: TYPE) -> void:
	if SettingsManager.get_debug_enabled():
		Printer.debug("Loading modules of type '%s' ..." % get_type_string(type))
	var path := get_custom_modules_folder(type)
	# Creating necesarry folders if not existing already
	DirAccess.make_dir_recursive_absolute(path)
	DirAccess.make_dir_recursive_absolute(get_config_folder(type))
	# Loading in all custom module files of 'type'
	var module_files := DirAccess.get_files_at(path)
	if module_files.size() == 0:
		return
	for file: String in module_files:
		if Toolbox.check_extension(file, ["pck"]):
			ProjectSettings.load_resource_pack(path + file, false)


func get_type_string(type: TYPE) -> String:
	match type:
		TYPE.LAYOUT: return "layouts"
		TYPE.MODULE: return "modules"
		TYPE.EFFECT: return "effects"
		TYPE.TRANSITION: return "transitions"
		TYPE.RENDER_PROFILE: return "render_profiles"
		_: return ""


func get_custom_modules_folder(type: TYPE) -> String:
	return "user://modules/%s/" % get_type_string(type)


func get_config_folder(type: TYPE) -> String:
	return "user://module_configs/%s/" % get_type_string(type)


func get_config_file(type: TYPE, file_name: String) -> String:
	return get_config_folder(type) + file_name


func get_module_info(type: TYPE, module_name: String) -> Module:
	return load("res://_%s/%s/info.tres" % [
		get_type_string(type), module_name])


func get_layout_info(layout_name: String) -> LayoutModule:
	return load("res://_%s/layout_%s/info.tres" % [
		get_type_string(TYPE.LAYOUT), layout_name])


func create_module_id(type: TYPE, module_name: String) -> String:
	var config_dir_files := DirAccess.get_files_at(get_config_folder(type))
	var new_name := "%s-%s" % [module_name, randi_range(100000, 999999)]
	while new_name in config_dir_files:
		new_name = "%s-%s" % [module_name, randi_range(100000, 999999)]
	return new_name


func remove_config_layout(type: String, instance_name: String) -> void:
	DirAccess.remove_absolute("%s%s.cfg" % [
		ProjectSettings.get_setting("globals/path/configs/%s" % type), 
		instance_name])
