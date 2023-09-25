extends Node


var modules := {}


func _ready() -> void:
	# Creating modules dir in user:// if doesn't exist
	var dir := DirAccess.open("user://")
	if !dir.dir_exists("modules"):
		dir.make_dir("modules")
		return
	
	# Loading in all saved custom modules
	dir.change_dir("modules")
	for module_type in dir.get_directories():
		dir.change_dir(module_type)
		for module_name in dir.get_files():
			_load_custom_module(module_type, module_name)
		dir.change_dir("..")
	
	# Populating the modules dictionary
	dir = DirAccess.open("res://modules")
	for module_type in dir.get_directories():
		modules[module_type] = {}
		dir.change_dir(module_type)
		for module_folder in dir.get_directories():
			var path := "res://modules/%s/%s/info.tres" % [module_type, module_folder]
			if !FileAccess.file_exists(path):
				printerr("There is no ModuleInterface resource called 'info.tres' in %s!" % path)
				continue
			var info: ModuleInterface = load(path)
			modules[module_type][info.module_name.to_lower()] = info.scene
		dir.change_dir("..")


func _load_custom_module(module_type: String, module_name: String) -> void:
	if !ProjectSettings.load_resource_pack("user://modules/%s/%s" % [module_type, module_name]):
		printerr("Could not load '%s'" % module_name)


## Only way to add custom modules is by putting the file in 'user://modules/...'
func _add_custom_module(_module_type: String, _module_name: String) -> void:
	# TODO: A way to add a custom module, after adding it needs to be loaded
	# TODO: Open file explorer and get the required file.
	# TODO: Check if module type folder actually exists
	# TODO: Add it to modules dictionary as well
	pass


# SELECTED MODULES STUFF  ####################################

func get_selected_module_keys() -> PackedStringArray:
	if SettingsManager.data.has_section("selected_modules"):
		return SettingsManager.data.get_section_keys("selected_modules")
	return []


func get_selected_module(module_type: String) -> Node:
	if !get_selected_module_keys().has(module_type):
		SettingsManager.data.set_value("selected_modules", module_type, "default")
		SettingsManager.data.save(SettingsManager.PATH)
	var selected_module: String = SettingsManager.data.get_value("selected_modules",module_type, "default")
	return load(modules[module_type][selected_module]).instantiate()


func change_selected_module(module_type: String, module_name: String) -> void:
	SettingsManager.data.set_value("selected_modules", module_type, module_name)
	SettingsManager.data.save(SettingsManager.PATH)
