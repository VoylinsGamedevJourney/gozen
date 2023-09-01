extends Node

const PATH_SEL_MODULES := "user://selected_modules"


var modules := {}
var selected_modules := {}


func _ready() -> void:
	if FileAccess.file_exists(PATH_SEL_MODULES):
		selected_modules = str_to_var(FileManager.load_data(PATH_SEL_MODULES))
	
	var dir := DirAccess.open("user://")
	if !dir.dir_exists("modules"):
		dir.make_dir("modules")
	
	dir.change_dir("modules")
	for module_type in dir.get_directories():
		dir.change_dir(module_type)
		for module_name in dir.get_files():
			_load_custom_module(module_type, module_name)
		dir.change_dir("..")
	
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
func _add_custom_module(module_type: String, module_name: String) -> void:
	# TODO: A way to add a custom module, after adding it needs to be loaded
	# TODO: Open file explorer and get the required file.
	# TODO: Check if module type folder actually exists
	# TODO: Add it to modules dictionary as well
	pass


# SELECTED MODULES STUFF  ####################################

func get_selected_modules() -> Dictionary:
	return selected_modules


func get_selected_module(module_type: String) -> Node:
	if !selected_modules.has(module_type):
		selected_modules[module_type] = "Default"
		FileManager.save_data(selected_modules, PATH_SEL_MODULES)
	if !modules[module_type].has(selected_modules[module_type].to_lower()):
		return Node.new()
	return load(modules[module_type][selected_modules[module_type].to_lower()]).instantiate()


func change_selected_module(module_type: String, module_name: String) -> void:
	selected_modules[module_type] = module_name
	FileManager.save_data(selected_modules, PATH_SEL_MODULES)
